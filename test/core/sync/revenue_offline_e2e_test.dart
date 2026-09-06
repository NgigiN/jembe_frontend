// Golden end-to-end test for the offline-first revenue pipeline (Task 8b —
// see `.superpowers/sdd/2026-09-05-offline-first-p3-frontend-entity-rollout/task-8b-brief.md`).
//
// Mirrors `test/core/sync/harvest_offline_e2e_test.dart` (the FK-child
// golden): wires the REAL collaborators together — a real
// `AppDatabase.forTesting` (in-memory sqlite via drift), real
// `OutboxDao`/`SyncCursorDao`/`RevenueLocalDataSource`, a real
// `RevenueSyncer` and a real `SyncEngine`, driven through a real
// `RevenueRepositoryImpl` — and proves the whole loop converges against a
// fake in-memory "server". Only the network boundary
// (`RevenueRemoteDataSource`, `DeletionsApplier`) and the OS connectivity
// signal are faked.
//
// Every revenue created here targets an ALREADY-SYNCED parent source (whose
// id is already a server id) — P3 scope per `revenue_model.dart`'s
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
import 'package:farm_tracker/features/farm/data/datasources/revenue_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/revenue_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/revenue_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `revenue` entity.
///
/// Mirrors the P1 REST semantics this pilot targets: `addRevenue` mints a
/// server id and is idempotent on `client_uuid`; `getRevenues(updatedSince:)`
/// returns rows whose `updatedAt >= updatedSince` (or every row when null) —
/// the sync pull always calls it this way, never with `source`/date
/// filters. [seedServerRow] lets a test inject a server-side row directly —
/// e.g. to simulate a change made from another device.
class _FakeRevenueRemoteDataSource implements RevenueRemoteDataSource {
  final Map<String, RevenueModel> _byServerId = <String, RevenueModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  /// Every `client_uuid` [addRevenue] was ever called with, in call order.
  final List<String> addRevenueClientUuids = <String>[];

  /// Every row currently held by the fake server.
  List<RevenueModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<RevenueModel> addRevenue(RevenueModel revenue) async {
    addRevenueClientUuids.add(revenue.clientUuid);
    final existingServerId = _serverIdByClientUuid[revenue.clientUuid];
    if (existingServerId != null) {
      // Idempotent replay: same clientUuid comes back as the SAME row.
      return _byServerId[existingServerId]!;
    }

    final serverId = '${_nextId++}';
    final stored = RevenueModel(
      id: serverId,
      clientUuid: revenue.clientUuid,
      userId: revenue.userId,
      source: revenue.source,
      sourceId: revenue.sourceId,
      type: revenue.type,
      quantity: revenue.quantity,
      unitPrice: revenue.unitPrice,
      total: revenue.total,
      date: revenue.date,
      notes: revenue.notes,
      createdAt: revenue.createdAt,
      updatedAt: revenue.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[revenue.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<RevenueModel> updateRevenue(RevenueModel revenue) async {
    final existing = _byServerId[revenue.id];
    final stored = RevenueModel(
      id: revenue.id,
      clientUuid: existing?.clientUuid ?? revenue.clientUuid,
      userId: revenue.userId,
      source: revenue.source,
      sourceId: revenue.sourceId,
      type: revenue.type,
      quantity: revenue.quantity,
      unitPrice: revenue.unitPrice,
      total: revenue.total,
      date: revenue.date,
      notes: revenue.notes,
      createdAt: existing?.createdAt ?? revenue.createdAt,
      updatedAt: revenue.updatedAt,
    );
    _byServerId[revenue.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteRevenue(String id) async {
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<RevenueModel> getRevenueById(String id) async {
    return _byServerId[id]!;
  }

  @override
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedSince,
  }) async {
    Iterable<RevenueModel> rows = _byServerId.values;
    if (source != null && source.isNotEmpty) {
      rows = rows.where((row) => row.source == source);
    }
    if (updatedSince != null) {
      rows = rows.where((row) => !row.updatedAt.isBefore(updatedSince));
    }
    return rows.toList();
  }

  /// Test-only: injects/replaces a server-side row directly, bypassing
  /// [addRevenue] — simulates an inbound change from another device.
  void seedServerRow(RevenueModel row) {
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

  final RevenueLocalDataSource _local;
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
    local = RevenueLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeRevenueRemoteDataSource();
    deletions = _FakeDeletionsApplier(local);
    connectivity = _FakeConnectivityService();
    final syncer = RevenueSyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
    );
    repo = RevenueRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final RevenueLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeRevenueRemoteDataSource remote;
  late final _FakeDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final RevenueRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Builds a [RevenueModel] for seeding the local mirror or the fake server
/// directly (bypassing the repository). Targets an already-synced parent
/// source (server id `'901'`).
RevenueModel _revenue({
  required String clientUuid,
  String id = '',
  String source = 'plant',
  String sourceId = '901',
  double quantity = 10,
  double unitPrice = 50,
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return RevenueModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    source: source,
    sourceId: sourceId,
    type: 'Maize Harvest',
    quantity: quantity,
    unitPrice: unitPrice,
    total: quantity * unitPrice,
    date: date ?? at,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
Revenue _unwrap(Either<Failure, Revenue> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    revenue,
  ) => revenue);
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
    'reconnect + syncNow converges: server has both revenues with the edit '
    'applied, local serverIds are populated, outbox is empty',
    () async {
      h.connectivity.online = false;

      final revenue1 = _unwrap(
        await h.repo.addRevenue(
          source: 'plant',
          sourceId: '901',
          type: 'Maize Harvest',
          quantity: 10,
          unitPrice: 50,
          date: DateTime.utc(2026, 1),
        ),
      );
      final revenue2 = _unwrap(
        await h.repo.addRevenue(
          source: 'animal',
          sourceId: '902',
          type: 'Milk Sale',
          quantity: 20,
          unitPrice: 5,
          date: DateTime.utc(2026, 2),
        ),
      );

      await h.repo.updateRevenue(
        id: revenue2.id,
        source: revenue2.source,
        sourceId: revenue2.sourceId,
        type: revenue2.type,
        quantity: 25,
        unitPrice: revenue2.unitPrice,
        total: 25 * revenue2.unitPrice,
        date: revenue2.date,
        notes: revenue2.notes,
      );

      // --- Outbox coalesced BEFORE any sync attempt ---
      final pendingRows = await h.outbox.peekAll();
      expect(pendingRows.map((r) => r.clientUuid).toSet(), {
        revenue1.id,
        revenue2.id,
      });
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
      expect(serverQuantities[revenue1.id], 10);
      expect(serverQuantities[revenue2.id], 25);

      final local1 = await h.local.getByClientUuid(revenue1.id);
      final local2 = await h.local.getByClientUuid(revenue2.id);
      expect(local1, isNotNull);
      expect(local2, isNotNull);
      expect(local1!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2.quantity, 25);

      // The already-synced parent source id is pushed through untouched
      // (P3 scope — no clientUuid->serverId FK translation attempted).
      final pushed = h.remote.allRows.firstWhere(
        (r) => r.clientUuid == revenue1.id,
      );
      expect(pushed.sourceId, '901');
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addRevenue for the row',
    () async {
      h.connectivity.online = false;

      final ghost = _unwrap(
        await h.repo.addRevenue(
          source: 'plant',
          sourceId: '901',
          type: 'Maize Harvest',
          quantity: 99,
          unitPrice: 1,
          date: DateTime.utc(2026),
        ),
      );
      await h.repo.deleteRevenue(ghost.id);

      final rows = await h.outbox.peekAll();
      expect(rows.where((r) => r.clientUuid == ghost.id), isEmpty);
      expect(rows, isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addRevenueClientUuids, isNot(contains(ghost.id)));
      expect(h.remote.allRows, isEmpty);

      final visible = await h.local.watchRevenues().first;
      expect(visible, isEmpty);
    },
  );

  test(
    'inbound update: a newer server row overwrites the local mirror on '
    'pull',
    () async {
      await h.local.upsert(
        _revenue(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          quantity: 5,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );

      h.remote.seedServerRow(
        _revenue(
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
    'row, which then disappears from watchRevenues',
    () async {
      await h.local.upsert(
        _revenue(clientUuid: 'cu-tombstoned', id: 'srv-2'),
        pending: false,
      );
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNotNull);

      h.deletions.addTombstone('cu-tombstoned');

      await h.engine.syncNow();

      expect(h.deletions.applyCount, 1);
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNull);

      final visible = await h.local.watchRevenues().first;
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
        _revenue(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          quantity: 1,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _revenue(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          quantity: 2,
          updatedAt: DateTime.utc(2026, 3),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _revenue(
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
        _revenue(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          quantity: 1,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _revenue(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          quantity: 2,
          updatedAt: DateTime.utc(2026, 2),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _revenue(
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
    'watchRevenues() stays UNFILTERED (R1) through an offline create + '
    'reconnect sync — both sources appear',
    () async {
      h.connectivity.online = false;

      await h.repo.addRevenue(
        source: 'plant',
        sourceId: '901',
        type: 'Maize Harvest',
        quantity: 7,
        unitPrice: 1,
        date: DateTime.utc(2026),
      );
      await h.repo.addRevenue(
        source: 'animal',
        sourceId: '903',
        type: 'Milk Sale',
        quantity: 999,
        unitPrice: 1,
        date: DateTime.utc(2026),
      );

      final all = await h.local.watchRevenues().first;
      expect(all, hasLength(2));
      expect(all.map((r) => r.source).toSet(), {'plant', 'animal'});

      h.connectivity.online = true;
      await h.engine.syncNow();

      final allAfterSync = await h.local.watchRevenues().first;
      expect(allAfterSync, hasLength(2));
    },
  );
}
