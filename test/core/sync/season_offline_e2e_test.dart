// Golden end-to-end tests for the offline-first season pipeline (the FK
// child batch — see `.superpowers/sdd/2026-09-05-offline-first-p3-frontend-entity-rollout/task-6-brief.md`).
//
// Mirrors `test/core/sync/offline_e2e_test.dart` (the `land` golden): wires
// the REAL collaborators together — a real `AppDatabase.forTesting`
// (in-memory sqlite via drift), real `OutboxDao`/`SyncCursorDao`/
// `SeasonLocalDataSource`, a real `SeasonSyncer` and a real `SyncEngine`,
// driven through a real `SeasonRepositoryImpl` — and proves the whole loop
// converges against a fake in-memory "server". Only the network boundary
// (`SeasonRemoteDataSource`, `DeletionsApplier`) and the OS connectivity
// signal are faked.
//
// Every season created here targets an ALREADY-SYNCED parent (a plant/land
// whose id is already a server id) — P3 scope per `season_model.dart`'s
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
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/season_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/season_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `season` entity.
///
/// Mirrors the P1 REST semantics this pilot targets: `addSeason` mints a
/// server id and is idempotent on `client_uuid`; `getSeasons(updatedSince:)`
/// returns rows whose `updatedAt >= updatedSince` (or every row when null).
/// [seedServerRow] lets a test inject a server-side row directly — e.g. to
/// simulate a change made from another device.
class _FakeSeasonRemoteDataSource implements SeasonRemoteDataSource {
  final Map<String, SeasonModel> _byServerId = <String, SeasonModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  /// Every `client_uuid` [addSeason] was ever called with, in call order.
  final List<String> addSeasonClientUuids = <String>[];

  /// Every row currently held by the fake server.
  List<SeasonModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<SeasonModel> addSeason(SeasonModel season) async {
    addSeasonClientUuids.add(season.clientUuid);
    final existingServerId = _serverIdByClientUuid[season.clientUuid];
    if (existingServerId != null) {
      // Idempotent replay: same clientUuid comes back as the SAME row.
      return _byServerId[existingServerId]!;
    }

    final serverId = '${_nextId++}';
    final stored = SeasonModel(
      id: serverId,
      clientUuid: season.clientUuid,
      userId: season.userId,
      name: season.name,
      plantId: season.plantId,
      landId: season.landId,
      startDate: season.startDate,
      endDate: season.endDate,
      createdAt: season.createdAt,
      updatedAt: season.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[season.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<SeasonModel> updateSeason(SeasonModel season) async {
    final existing = _byServerId[season.id];
    final stored = SeasonModel(
      id: season.id,
      clientUuid: existing?.clientUuid ?? season.clientUuid,
      userId: season.userId,
      name: season.name,
      plantId: season.plantId,
      landId: season.landId,
      startDate: season.startDate,
      endDate: season.endDate,
      createdAt: existing?.createdAt ?? season.createdAt,
      updatedAt: season.updatedAt,
    );
    _byServerId[season.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteSeason(String id) async {
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<List<SeasonModel>> getSeasons({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    if (updatedSince == null) return allRows;
    return _byServerId.values
        .where((row) => !row.updatedAt.isBefore(updatedSince))
        .toList();
  }

  /// Test-only: injects/replaces a server-side row directly, bypassing
  /// [addSeason] — simulates an inbound change from another device.
  void seedServerRow(SeasonModel row) {
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

  final SeasonLocalDataSource _local;
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
    local = SeasonLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeSeasonRemoteDataSource();
    deletions = _FakeDeletionsApplier(local);
    connectivity = _FakeConnectivityService();
    final syncer = SeasonSyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
    );
    repo = SeasonRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final SeasonLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeSeasonRemoteDataSource remote;
  late final _FakeDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final SeasonRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Builds a domain [Season] targeting an already-synced parent (numeric
/// server ids `'501'` / `'601'` — P4's `translateSeasonFks` passes a
/// numeric-string FK through untouched, same as an unsynced clientUuid it
/// has resolved).
Season _domainSeason({
  String id = '',
  String name = 'Season',
  DateTime? startDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return Season(
    id: id,
    userId: 'user-1',
    name: name,
    plantId: '501',
    landId: '601',
    startDate: startDate ?? at,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Builds a [SeasonModel] for seeding the local mirror or the fake server
/// directly (bypassing the repository).
SeasonModel _season({
  required String clientUuid,
  String id = '',
  String name = 'Season',
  DateTime? startDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return SeasonModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    plantId: '501',
    landId: '601',
    startDate: startDate ?? at,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
Season _unwrap(Either<Failure, Season> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    season,
  ) => season);
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
    'reconnect + syncNow converges: server has both seasons with the edit '
    'applied, local serverIds are populated, outbox is empty',
    () async {
      h.connectivity.online = false;

      final season1 = _unwrap(
        await h.repo.addSeason(_domainSeason(name: 'Long Rains')),
      );
      final season2 = _unwrap(
        await h.repo.addSeason(_domainSeason(name: 'Short Rains')),
      );

      await h.repo.updateSeason(
        Season(
          id: season2.id,
          userId: season2.userId,
          name: 'Short Rains Edited',
          plantId: season2.plantId,
          landId: season2.landId,
          startDate: season2.startDate,
          createdAt: season2.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      // --- Outbox coalesced BEFORE any sync attempt ---
      final pendingRows = await h.outbox.peekAll();
      expect(
        pendingRows.map((r) => r.clientUuid).toSet(),
        {season1.id, season2.id},
      );
      expect(pendingRows.every((r) => r.op == 'create'), isTrue);
      expect(pendingRows, hasLength(2));

      // --- Reconnect and converge ---
      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(await h.outbox.peekAll(), isEmpty);
      expect(h.remote.allRows, hasLength(2));

      final serverNames = {
        for (final r in h.remote.allRows) r.clientUuid: r.name,
      };
      expect(serverNames[season1.id], 'Long Rains');
      expect(serverNames[season2.id], 'Short Rains Edited');

      final local1 = await h.local.getByClientUuid(season1.id);
      final local2 = await h.local.getByClientUuid(season2.id);
      expect(local1, isNotNull);
      expect(local2, isNotNull);
      expect(local1!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2.name, 'Short Rains Edited');

      // The already-synced (numeric) parent ids are pushed through
      // untouched by translateSeasonFks — no FK translation needed.
      final pushed = h.remote.allRows.firstWhere(
        (r) => r.clientUuid == season1.id,
      );
      expect(pushed.plantId, '501');
      expect(pushed.landId, '601');
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addSeason for the row',
    () async {
      h.connectivity.online = false;

      final ghost = _unwrap(
        await h.repo.addSeason(_domainSeason(name: 'Ghost Season')),
      );
      await h.repo.deleteSeason(ghost.id);

      final rows = await h.outbox.peekAll();
      expect(rows.where((r) => r.clientUuid == ghost.id), isEmpty);
      expect(rows, isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addSeasonClientUuids, isNot(contains(ghost.id)));
      expect(h.remote.allRows, isEmpty);

      final visible = await h.local.watchSeasons().first;
      expect(visible, isEmpty);
    },
  );

  test(
    'inbound update: a newer server row overwrites the local mirror on '
    'pull',
    () async {
      await h.local.upsert(
        _season(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          name: 'Old name',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );

      h.remote.seedServerRow(
        _season(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          name: 'New name from server',
          updatedAt: DateTime.utc(2026, 6),
        ),
      );

      await h.engine.syncNow();

      final row = await h.local.getByClientUuid('cu-inbound-update');
      expect(row, isNotNull);
      expect(row!.name, 'New name from server');
      expect(row.pending, isFalse);
    },
  );

  test(
    'inbound tombstone: a server-reported deletion hard-deletes the local '
    'row, which then disappears from watchSeasons',
    () async {
      await h.local.upsert(
        _season(clientUuid: 'cu-tombstoned', id: 'srv-2'),
        pending: false,
      );
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNotNull);

      h.deletions.addTombstone('cu-tombstoned');

      await h.engine.syncNow();

      expect(h.deletions.applyCount, 1);
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNull);

      final visible = await h.local.watchSeasons().first;
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
        _season(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'Base',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _season(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'Local newer edit',
          updatedAt: DateTime.utc(2026, 3),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _season(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'Server older value',
          updatedAt: DateTime.utc(2026, 2),
        ),
      );

      await h.engine.syncNow();

      final localWinsRow = await h.local.getByClientUuid(
        'cu-lww-local-wins',
      );
      expect(localWinsRow, isNotNull);
      expect(localWinsRow!.name, 'Local newer edit');
      expect(localWinsRow.pending, isTrue);

      // --- (b) server row is NEWER than the local pending edit: server
      // wins. ---
      await h.local.upsert(
        _season(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'Base',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _season(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'Local stale edit',
          updatedAt: DateTime.utc(2026, 2),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _season(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'Server newer value',
          updatedAt: DateTime.utc(2026, 4),
        ),
      );

      await h.engine.syncNow();

      final serverWinsRow = await h.local.getByClientUuid(
        'cu-lww-server-wins',
      );
      expect(serverWinsRow, isNotNull);
      expect(serverWinsRow!.name, 'Server newer value');
      expect(serverWinsRow.pending, isFalse);
    },
  );
}
