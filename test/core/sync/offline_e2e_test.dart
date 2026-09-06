// Golden end-to-end tests for the offline-first land pipeline.
//
// Unlike the unit-level tests (`land_syncer_test.dart`, `sync_engine_test.dart`,
// `land_repository_impl_test.dart`), this file wires the REAL collaborators
// together — a real `AppDatabase.forTesting` (in-memory sqlite via drift),
// real `OutboxDao`/`SyncCursorDao`/`LandLocalDataSource`, a real `LandSyncer`
// and a real `SyncEngine` — driven through a real `LandRepositoryImpl`, and
// proves the whole loop converges against a fake in-memory "server". Only the
// network boundary (`LandRemoteDataSource`, `DeletionsApplier`) and the OS
// connectivity signal are faked.
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
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/land_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `land` entity.
///
/// Mirrors the P1 REST semantics this pilot targets: `addLand` mints a
/// server id and is idempotent on `client_uuid` (a retried create for a
/// clientUuid already known server-side returns the SAME stored row rather
/// than creating a duplicate); `getLands(updatedSince:)` returns rows whose
/// `updatedAt >= updatedSince` (or every row when null, matching a full
/// pull). [seedServerRow] lets a test inject a server-side row directly —
/// e.g. to simulate a change made from another device — without going
/// through [addLand]/[updateLand].
class _FakeLandRemoteDataSource implements LandRemoteDataSource {
  final Map<String, LandModel> _byServerId = <String, LandModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  /// Every `client_uuid` [addLand] was ever called with, in call order —
  /// lets a test assert a row was NEVER pushed (e.g. an offline
  /// create+delete that annihilated in the outbox before syncing).
  final List<String> addLandClientUuids = <String>[];

  /// Every row currently held by the fake server.
  List<LandModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<LandModel> addLand(LandModel land) async {
    addLandClientUuids.add(land.clientUuid);
    final existingServerId = _serverIdByClientUuid[land.clientUuid];
    if (existingServerId != null) {
      // Idempotent replay: same clientUuid comes back as the SAME row,
      // never a duplicate — mirrors P1's (user_id, client_uuid) key.
      return _byServerId[existingServerId]!;
    }

    final serverId = '${_nextId++}';
    final stored = LandModel(
      id: serverId,
      clientUuid: land.clientUuid,
      userId: land.userId,
      name: land.name,
      size: land.size,
      location: land.location,
      soilType: land.soilType,
      tenureType: land.tenureType,
      createdAt: land.createdAt,
      updatedAt: land.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[land.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<LandModel> updateLand(LandModel land) async {
    final existing = _byServerId[land.id];
    final stored = LandModel(
      id: land.id,
      clientUuid: existing?.clientUuid ?? land.clientUuid,
      userId: land.userId,
      name: land.name,
      size: land.size,
      location: land.location,
      soilType: land.soilType,
      tenureType: land.tenureType,
      createdAt: existing?.createdAt ?? land.createdAt,
      updatedAt: land.updatedAt,
    );
    _byServerId[land.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteLand(String id) async {
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<List<LandModel>> getLands({DateTime? updatedSince}) async {
    if (updatedSince == null) return allRows;
    return _byServerId.values
        .where((row) => !row.updatedAt.isBefore(updatedSince))
        .toList();
  }

  /// Test-only: injects/replaces a server-side row directly, bypassing
  /// [addLand] — simulates an inbound change (update or a fresh row) from a
  /// source other than this client, with a specific `updatedAt`.
  void seedServerRow(LandModel row) {
    _byServerId[row.id] = row;
    if (row.clientUuid.isNotEmpty) {
      _serverIdByClientUuid[row.clientUuid] = row.id;
    }
  }
}

/// Fake `/sync/deletions` applier: a test [addTombstone]s a `clientUuid` and
/// the next [applyDeletions] hard-deletes that row locally — mirroring what
/// the real `DeletionsDataSource` does with the server's tombstone feed.
class _FakeDeletionsApplier implements DeletionsApplier {
  _FakeDeletionsApplier(this._local);

  final LandLocalDataSource _local;
  final List<String> _pendingTombstones = <String>[];
  int applyCount = 0;

  /// Queues [clientUuid] to be hard-deleted locally on the next
  /// [applyDeletions] call.
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
    local = LandLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeLandRemoteDataSource();
    deletions = _FakeDeletionsApplier(local);
    connectivity = _FakeConnectivityService();
    final syncer = LandSyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
    );
    repo = LandRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final LandLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeLandRemoteDataSource remote;
  late final _FakeDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final LandRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Builds a domain [Land] to pass into the repository.
Land _domainLand({
  String id = '',
  String name = 'Land',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return Land(
    id: id,
    userId: 'user-1',
    name: name,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Builds a [LandModel] for seeding the local mirror or the fake server
/// directly (bypassing the repository).
LandModel _land({
  required String clientUuid,
  String id = '',
  String name = 'North Field',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return LandModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
Land _unwrap(Either<Failure, Land> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    land,
  ) => land);
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
    'offline burst (3 creates, 1 edit, 1 delete) coalesces in the outbox, '
    'then reconnect + syncNow converges: server has 2 lands with the edit '
    'applied, local serverIds are populated, outbox is empty',
    () async {
      h.connectivity.online = false;

      final land1 = _unwrap(
        await h.repo.addLand(_domainLand(name: 'Land One')),
      );
      final land2 = _unwrap(
        await h.repo.addLand(_domainLand(name: 'Land Two')),
      );
      final land3 = _unwrap(
        await h.repo.addLand(_domainLand(name: 'Land Three')),
      );

      await h.repo.updateLand(
        Land(
          id: land2.id,
          userId: land2.userId,
          name: 'Land Two Edited',
          createdAt: land2.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      await h.repo.deleteLand(land3.id);

      // --- Outbox coalesced BEFORE any sync attempt ---
      final pendingRows = await h.outbox.peekAll();
      expect(
        pendingRows.map((r) => r.clientUuid).toSet(),
        {land1.id, land2.id},
        reason:
            'land3 (create+delete) must have annihilated; land1/land2 '
            'survive as single create entries',
      );
      expect(pendingRows.every((r) => r.op == 'create'), isTrue);
      expect(pendingRows, hasLength(2));

      // --- Reconnect and converge ---
      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(await h.outbox.peekAll(), isEmpty);
      expect(h.remote.allRows, hasLength(2));
      expect(
        h.remote.addLandClientUuids,
        isNot(contains(land3.id)),
        reason: 'the annihilated create must NEVER reach the fake server',
      );

      final serverNames = {
        for (final r in h.remote.allRows) r.clientUuid: r.name,
      };
      expect(serverNames[land1.id], 'Land One');
      expect(serverNames[land2.id], 'Land Two Edited');

      final local1 = await h.local.getByClientUuid(land1.id);
      final local2 = await h.local.getByClientUuid(land2.id);
      expect(local1, isNotNull);
      expect(local2, isNotNull);
      expect(local1!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2.name, 'Land Two Edited');

      final visible = await h.local.watchLands().first;
      final visibleUuids = visible.map((m) => m.clientUuid).toSet();
      expect(visibleUuids, containsAll([land1.id, land2.id]));
      expect(visibleUuids, isNot(contains(land3.id)));
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addLand for the row',
    () async {
      h.connectivity.online = false;

      final ghost = _unwrap(
        await h.repo.addLand(_domainLand(name: 'Ghost Field')),
      );
      await h.repo.deleteLand(ghost.id);

      // Nothing survives in the outbox for this clientUuid.
      final rows = await h.outbox.peekAll();
      expect(rows.where((r) => r.clientUuid == ghost.id), isEmpty);
      expect(rows, isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addLandClientUuids, isNot(contains(ghost.id)));
      expect(h.remote.allRows, isEmpty);

      // Invisible through the reactive read, regardless of what happened to
      // the underlying local tombstone row.
      final visible = await h.local.watchLands().first;
      expect(visible, isEmpty);
    },
  );

  test(
    'inbound update: a newer server row overwrites the local mirror on pull',
    () async {
      await h.local.upsert(
        _land(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          name: 'Old name',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );

      h.remote.seedServerRow(
        _land(
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
    'row, which then disappears from watchLands',
    () async {
      await h.local.upsert(
        _land(clientUuid: 'cu-tombstoned', id: 'srv-2'),
        pending: false,
      );
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNotNull);

      h.deletions.addTombstone('cu-tombstoned');

      await h.engine.syncNow();

      expect(h.deletions.applyCount, 1);
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNull);

      final visible = await h.local.watchLands().first;
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
      // wins, the server value is NOT applied. ---
      await h.local.upsert(
        _land(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'Base',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _land(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'Local newer edit',
          updatedAt: DateTime.utc(2026, 3),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _land(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'Server older value',
          updatedAt: DateTime.utc(2026, 2),
        ),
      );

      await h.engine.syncNow();

      final localWinsRow = await h.local.getByClientUuid('cu-lww-local-wins');
      expect(localWinsRow, isNotNull);
      expect(localWinsRow!.name, 'Local newer edit');
      expect(localWinsRow.pending, isTrue);

      // --- (b) server row is NEWER than the local pending edit: server
      // wins, overwriting the local edit and clearing `pending`. ---
      await h.local.upsert(
        _land(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'Base',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _land(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'Local stale edit',
          updatedAt: DateTime.utc(2026, 2),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _land(
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

      // The first (local-wins) row must be unaffected by the second sync
      // pass's cursor advance re-processing it (idempotent re-pull).
      final localWinsRowAfter = await h.local.getByClientUuid(
        'cu-lww-local-wins',
      );
      expect(localWinsRowAfter!.name, 'Local newer edit');
      expect(localWinsRowAfter.pending, isTrue);
    },
  );
}
