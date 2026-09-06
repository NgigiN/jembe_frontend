// Golden end-to-end test for the offline-first harvest pipeline (Task 7a —
// see `.superpowers/sdd/2026-09-05-offline-first-p3-frontend-entity-rollout/task-7-brief.md`).
//
// Mirrors `test/core/sync/season_offline_e2e_test.dart` (the FK-child
// golden): wires the REAL collaborators together — a real
// `AppDatabase.forTesting` (in-memory sqlite via drift), real
// `OutboxDao`/`SyncCursorDao`/`HarvestLocalDataSource`, a real
// `HarvestSyncer` and a real `SyncEngine`, driven through a real
// `HarvestRepositoryImpl` — and proves the whole loop converges against a
// fake in-memory "server". Only the network boundary
// (`HarvestRemoteDataSource`, `DeletionsApplier`) and the OS connectivity
// signal are faked.
//
// Every harvest created here targets an ALREADY-SYNCED parent season (whose
// id is already a server id) — P3 scope per `harvest_model.dart`'s
// `// TODO(P4)` note; reconciling an unsynced parent's clientUuid into a
// server id is out of scope for this rollout.
import 'package:dartz/dartz.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/harvest_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/harvest_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `harvest` entity.
///
/// Mirrors the P1 REST semantics this pilot targets: `addHarvest` mints a
/// server id and is idempotent on `client_uuid`; `getHarvests(updatedSince:)`
/// returns rows whose `updatedAt >= updatedSince` (or every row when null) —
/// the sync pull always calls it this way, never with `seasonId`.
/// [seedServerRow] lets a test inject a server-side row directly — e.g. to
/// simulate a change made from another device.
class _FakeHarvestRemoteDataSource implements HarvestRemoteDataSource {
  final Map<String, HarvestModel> _byServerId = <String, HarvestModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  /// Every `client_uuid` [addHarvest] was ever called with, in call order.
  final List<String> addHarvestClientUuids = <String>[];

  /// Every row currently held by the fake server.
  List<HarvestModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<HarvestModel> addHarvest(HarvestModel harvest) async {
    addHarvestClientUuids.add(harvest.clientUuid);
    final existingServerId = _serverIdByClientUuid[harvest.clientUuid];
    if (existingServerId != null) {
      // Idempotent replay: same clientUuid comes back as the SAME row.
      return _byServerId[existingServerId]!;
    }

    final serverId = '${_nextId++}';
    final stored = HarvestModel(
      id: serverId,
      clientUuid: harvest.clientUuid,
      seasonId: harvest.seasonId,
      quantity: harvest.quantity,
      unit: harvest.unit,
      date: harvest.date,
      notes: harvest.notes,
      revenueId: harvest.revenueId,
      createdAt: harvest.createdAt,
      updatedAt: harvest.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[harvest.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<HarvestModel> updateHarvest(HarvestModel harvest) async {
    final existing = _byServerId[harvest.id];
    final stored = HarvestModel(
      id: harvest.id,
      clientUuid: existing?.clientUuid ?? harvest.clientUuid,
      seasonId: harvest.seasonId,
      quantity: harvest.quantity,
      unit: harvest.unit,
      date: harvest.date,
      notes: harvest.notes,
      revenueId: harvest.revenueId,
      createdAt: existing?.createdAt ?? harvest.createdAt,
      updatedAt: harvest.updatedAt,
    );
    _byServerId[harvest.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteHarvest(String id) async {
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<List<HarvestModel>> getHarvests({
    String? seasonId,
    DateTime? updatedSince,
  }) async {
    Iterable<HarvestModel> rows = _byServerId.values;
    if (seasonId != null && seasonId.isNotEmpty) {
      rows = rows.where((row) => row.seasonId == seasonId);
    }
    if (updatedSince != null) {
      rows = rows.where((row) => !row.updatedAt.isBefore(updatedSince));
    }
    return rows.toList();
  }

  /// Test-only: injects/replaces a server-side row directly, bypassing
  /// [addHarvest] — simulates an inbound change from another device.
  void seedServerRow(HarvestModel row) {
    _byServerId[row.id] = row;
    if (row.clientUuid.isNotEmpty) {
      _serverIdByClientUuid[row.clientUuid] = row.id;
    }
  }
}

/// Fake `/sync/deletions` applier: a test [addTombstone]s a `clientUuid` and
/// the next [applyDeletions] hard-deletes that row locally.
class _FakeDeletionsApplier implements DeletionsApplier {
  _FakeDeletionsApplier(this._local);

  final HarvestLocalDataSource _local;
  final List<String> _pendingTombstones = <String>[];
  int applyCount = 0;

  void addTombstone(String clientUuid) => _pendingTombstones.add(clientUuid);

  @override
  Future<void> applyDeletions(DateTime? since) async {
    applyCount++;
    for (final clientUuid in _pendingTombstones) {
      await _local.hardDelete(clientUuid);
    }
  }
}

/// Controllable fake of [ConnectivityService] — a plain online/offline
/// switch a test flips directly, no platform channel involved.
class _FakeConnectivityService implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

/// Wires every REAL offline-first collaborator around one in-memory
/// [AppDatabase], plus the fakes at the network boundary.
class _Harness {
  _Harness() : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    local = HarvestLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeHarvestRemoteDataSource();
    deletions = _FakeDeletionsApplier(local);
    connectivity = _FakeConnectivityService();
    final syncer = HarvestSyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
    );
    repo = HarvestRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final HarvestLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeHarvestRemoteDataSource remote;
  late final _FakeDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final HarvestRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Builds a domain [Harvest] targeting an already-synced parent season
/// (server id `'server-season-1'`) to pass into the repository.
Harvest _domainHarvest({
  String id = '',
  double quantity = 10,
  String unit = 'kg',
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? notes,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return Harvest(
    id: id,
    seasonId: 'server-season-1',
    quantity: quantity,
    unit: unit,
    date: date ?? at,
    notes: notes,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Builds a [HarvestModel] for seeding the local mirror or the fake server
/// directly (bypassing the repository).
HarvestModel _harvest({
  required String clientUuid,
  String id = '',
  String seasonId = 'server-season-1',
  double quantity = 10,
  String unit = 'kg',
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return HarvestModel(
    id: id,
    clientUuid: clientUuid,
    seasonId: seasonId,
    quantity: quantity,
    unit: unit,
    date: date ?? at,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
Harvest _unwrap(Either<Failure, Harvest> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    harvest,
  ) => harvest);
}

void main() {
  late _Harness h;

  setUp(() {
    h = _Harness();
    OfflineConfig.enabled = true;
  });

  tearDown(() async {
    OfflineConfig.enabled = false;
    await h.dispose();
  });

  test(
    'offline burst (2 creates, 1 edit) coalesces in the outbox, then '
    'reconnect + syncNow converges: server has both harvests with the edit '
    'applied, local serverIds are populated, outbox is empty',
    () async {
      h.connectivity.online = false;

      final harvest1 = _unwrap(
        await h.repo.addHarvest(_domainHarvest(quantity: 10)),
      );
      final harvest2 = _unwrap(
        await h.repo.addHarvest(_domainHarvest(quantity: 20)),
      );

      await h.repo.updateHarvest(
        Harvest(
          id: harvest2.id,
          seasonId: harvest2.seasonId,
          quantity: 25,
          unit: harvest2.unit,
          date: harvest2.date,
          notes: harvest2.notes,
          revenueId: harvest2.revenueId,
          createdAt: harvest2.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      // --- Outbox coalesced BEFORE any sync attempt ---
      final pendingRows = await h.outbox.peekAll();
      expect(
        pendingRows.map((r) => r.clientUuid).toSet(),
        {harvest1.id, harvest2.id},
      );
      expect(pendingRows.every((r) => r.op == 'create'), isTrue);
      expect(pendingRows, hasLength(2));

      // --- Reconnect and converge ---
      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(await h.outbox.peekAll(), isEmpty);
      expect(h.remote.allRows, hasLength(2));

      final serverQuantities = {
        for (final r in h.remote.allRows) r.clientUuid: r.quantity,
      };
      expect(serverQuantities[harvest1.id], 10);
      expect(serverQuantities[harvest2.id], 25);

      final local1 = await h.local.getByClientUuid(harvest1.id);
      final local2 = await h.local.getByClientUuid(harvest2.id);
      expect(local1, isNotNull);
      expect(local2, isNotNull);
      expect(local1!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2.quantity, 25);

      // The already-synced parent season id is pushed through untouched
      // (P3 scope — no clientUuid->serverId FK translation attempted).
      final pushed = h.remote.allRows.firstWhere(
        (r) => r.clientUuid == harvest1.id,
      );
      expect(pushed.seasonId, 'server-season-1');
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addHarvest for the row',
    () async {
      h.connectivity.online = false;

      final ghost = _unwrap(
        await h.repo.addHarvest(_domainHarvest(quantity: 99)),
      );
      await h.repo.deleteHarvest(ghost.id);

      final rows = await h.outbox.peekAll();
      expect(rows.where((r) => r.clientUuid == ghost.id), isEmpty);
      expect(rows, isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addHarvestClientUuids, isNot(contains(ghost.id)));
      expect(h.remote.allRows, isEmpty);

      final visible = await h.local.watchHarvests().first;
      expect(visible, isEmpty);
    },
  );

  test(
    'inbound update: a newer server row overwrites the local mirror on '
    'pull',
    () async {
      await h.local.upsert(
        _harvest(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          quantity: 5,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );

      h.remote.seedServerRow(
        _harvest(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          quantity: 55,
          updatedAt: DateTime.utc(2026, 6),
        ),
      );

      await h.engine.syncNow();

      final row = await h.local.getByClientUuid('cu-inbound-update');
      expect(row, isNotNull);
      expect(row!.quantity, 55);
      expect(row.pending, isFalse);
    },
  );

  test(
    'inbound tombstone: a server-reported deletion hard-deletes the local '
    'row, which then disappears from watchHarvests',
    () async {
      await h.local.upsert(
        _harvest(clientUuid: 'cu-tombstoned', id: 'srv-2'),
        pending: false,
      );
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNotNull);

      h.deletions.addTombstone('cu-tombstoned');

      await h.engine.syncNow();

      expect(h.deletions.applyCount, 1);
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNull);

      final visible = await h.local.watchHarvests().first;
      expect(
        visible.map((m) => m.clientUuid),
        isNot(contains('cu-tombstoned')),
      );
    },
  );

  test(
    'LWW: a newer local pending edit beats a stale server row, and a newer '
    'server row beats a stale local pending edit',
    () async {
      // --- (a) local pending edit is NEWER than the server's row: local
      // wins. ---
      await h.local.upsert(
        _harvest(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          quantity: 1,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _harvest(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          quantity: 2,
          updatedAt: DateTime.utc(2026, 3),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _harvest(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          quantity: 3,
          updatedAt: DateTime.utc(2026, 2),
        ),
      );

      await h.engine.syncNow();

      final localWinsRow = await h.local.getByClientUuid(
        'cu-lww-local-wins',
      );
      expect(localWinsRow, isNotNull);
      expect(localWinsRow!.quantity, 2);
      expect(localWinsRow.pending, isTrue);

      // --- (b) server row is NEWER than the local pending edit: server
      // wins. ---
      await h.local.upsert(
        _harvest(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          quantity: 1,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _harvest(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          quantity: 2,
          updatedAt: DateTime.utc(2026, 2),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _harvest(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          quantity: 4,
          updatedAt: DateTime.utc(2026, 4),
        ),
      );

      await h.engine.syncNow();

      final serverWinsRow = await h.local.getByClientUuid(
        'cu-lww-server-wins',
      );
      expect(serverWinsRow, isNotNull);
      expect(serverWinsRow!.quantity, 4);
      expect(serverWinsRow.pending, isFalse);
    },
  );

  test(
    'watchHarvests(seasonId:) stays scoped to that season through an '
    'offline create + reconnect sync',
    () async {
      h.connectivity.online = false;

      await h.repo.addHarvest(_domainHarvest(quantity: 7));
      await h.repo.addHarvest(
        Harvest(
          id: '',
          seasonId: 'server-season-OTHER',
          quantity: 999,
          unit: 'kg',
          date: DateTime.utc(2026),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      final scoped = await h.local
          .watchHarvests(seasonId: 'server-season-1')
          .first;
      expect(scoped, hasLength(1));
      expect(scoped.single.quantity, 7);

      h.connectivity.online = true;
      await h.engine.syncNow();

      final scopedAfterSync = await h.local
          .watchHarvests(seasonId: 'server-season-1')
          .first;
      expect(scopedAfterSync, hasLength(1));
      expect(scopedAfterSync.single.quantity, 7);
    },
  );
}
