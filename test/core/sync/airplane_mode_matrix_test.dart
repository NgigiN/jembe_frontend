// Airplane-mode test matrix (P5d) — proves the offline loop across
// connectivity transitions on two representative entities: `land` (a
// standalone entity) and `season` (an FK child, targeting an
// already-synced parent per `season_offline_e2e_test.dart`'s P3 scope
// note).
//
// This complements (does not replace) the existing per-entity goldens
// (`offline_e2e_test.dart`, `season_offline_e2e_test.dart`, etc.), which
// already exercise these behaviors bundled into a handful of larger tests.
// Here each scenario is its own named test so the matrix reads as a
// checklist:
//   (a) create while offline        -> staged locally + queued, nothing sent
//   (b) reconnect                   -> the queued create syncs
//   (c) edit while offline          -> syncs on reconnect
//   (d) delete while offline        -> syncs as a tombstone on reconnect
//   (e) pull                        -> applies a server-side change locally
//   (f) LWW conflict                -> last-writer-wins, both directions
//
// Same wiring as the other goldens: a real `AppDatabase.forTesting`
// (in-memory sqlite via drift), real DAOs/local-data-sources/syncers, a
// real `SyncEngine`, driven through the real repository — only the network
// boundary (`*RemoteDataSource`, `DeletionsApplier`) and the OS
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
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/land_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/season_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/season_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controllable fake of [ConnectivityService] — a plain online/offline
/// switch a test flips directly, no platform channel involved. Shared by
/// both the `land` and `season` harnesses below.
class _FakeConnectivityService implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

// ---------------------------------------------------------------------------
// land
// ---------------------------------------------------------------------------

/// In-memory fake "server" for `land`, tracking every call so a test can
/// assert nothing was sent while offline.
class _FakeLandRemoteDataSource implements LandRemoteDataSource {
  final Map<String, LandModel> _byServerId = <String, LandModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  final List<String> addCalls = <String>[];
  final List<String> updateCalls = <String>[];
  final List<String> deleteCalls = <String>[];

  List<LandModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<LandModel> addLand(LandModel land) async {
    addCalls.add(land.clientUuid);
    final existingServerId = _serverIdByClientUuid[land.clientUuid];
    if (existingServerId != null) {
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
    updateCalls.add(land.id);
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
    deleteCalls.add(id);
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

  /// Test-only: injects/replaces a server-side row directly — simulates an
  /// inbound change from another device.
  void seedServerRow(LandModel row) {
    _byServerId[row.id] = row;
    if (row.clientUuid.isNotEmpty) {
      _serverIdByClientUuid[row.clientUuid] = row.id;
    }
  }
}

/// Fake `/sync/deletions` applier for `land`.
class _FakeLandDeletionsApplier implements DeletionsApplier {
  _FakeLandDeletionsApplier(this._local);

  final LandLocalDataSource _local;
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

/// Wires every REAL offline-first `land` collaborator around one in-memory
/// [AppDatabase], plus the fakes at the network boundary.
class _LandHarness {
  _LandHarness() : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    local = LandLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeLandRemoteDataSource();
    deletions = _FakeLandDeletionsApplier(local);
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
  late final _FakeLandDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final LandRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

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

Land _unwrapLand(Either<Failure, Land> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    land,
  ) => land);
}

// ---------------------------------------------------------------------------
// season (FK child)
// ---------------------------------------------------------------------------

/// In-memory fake "server" for `season`, tracking every call so a test can
/// assert nothing was sent while offline.
class _FakeSeasonRemoteDataSource implements SeasonRemoteDataSource {
  final Map<String, SeasonModel> _byServerId = <String, SeasonModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  final List<String> addCalls = <String>[];
  final List<String> updateCalls = <String>[];
  final List<String> deleteCalls = <String>[];

  List<SeasonModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<SeasonModel> addSeason(SeasonModel season) async {
    addCalls.add(season.clientUuid);
    final existingServerId = _serverIdByClientUuid[season.clientUuid];
    if (existingServerId != null) {
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
    updateCalls.add(season.id);
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
    deleteCalls.add(id);
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<List<SeasonModel>> getSeasons({DateTime? updatedSince}) async {
    if (updatedSince == null) return allRows;
    return _byServerId.values
        .where((row) => !row.updatedAt.isBefore(updatedSince))
        .toList();
  }

  /// Test-only: injects/replaces a server-side row directly — simulates an
  /// inbound change from another device.
  void seedServerRow(SeasonModel row) {
    _byServerId[row.id] = row;
    if (row.clientUuid.isNotEmpty) {
      _serverIdByClientUuid[row.clientUuid] = row.id;
    }
  }
}

/// Fake `/sync/deletions` applier for `season`.
class _FakeSeasonDeletionsApplier implements DeletionsApplier {
  _FakeSeasonDeletionsApplier(this._local);

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

/// Wires every REAL offline-first `season` collaborator around one
/// in-memory [AppDatabase], plus the fakes at the network boundary. Every
/// season here targets an ALREADY-SYNCED parent (numeric ids `'501'`/`'601'`)
/// — reconciling an unsynced parent's clientUuid is P4 scope, exercised in
/// `fk_reconciliation_e2e_test.dart`, not here.
class _SeasonHarness {
  _SeasonHarness() : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    local = SeasonLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeSeasonRemoteDataSource();
    deletions = _FakeSeasonDeletionsApplier(local);
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
  late final _FakeSeasonDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final SeasonRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

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

Season _unwrapSeason(Either<Failure, Season> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    season,
  ) => season);
}

// ---------------------------------------------------------------------------
// matrix
// ---------------------------------------------------------------------------

void main() {
  group('land — airplane mode matrix', () {
    late _LandHarness h;

    setUp(() {
      h = _LandHarness();
      OfflineConfig.enabled = true;
    });

    tearDown(() async {
      OfflineConfig.enabled = false;
      await h.dispose();
    });

    test(
      '(a) create while offline stages the row locally and queues it in the '
      'outbox; nothing is sent',
      () async {
        h.connectivity.online = false;

        final land = _unwrapLand(
          await h.repo.addLand(_domainLand(name: 'Offline Land')),
        );

        final localRow = await h.local.getByClientUuid(land.id);
        expect(localRow, isNotNull);
        expect(localRow!.pending, isTrue);
        expect(localRow.id, isEmpty, reason: 'no server id yet');

        final pendingRows = await h.outbox.peekAll();
        expect(pendingRows, hasLength(1));
        expect(pendingRows.single.clientUuid, land.id);
        expect(pendingRows.single.op, 'create');

        expect(h.remote.addCalls, isEmpty);
        expect(h.remote.allRows, isEmpty);
      },
    );

    test(
      '(b) reconnecting and syncing sends the queued create to the fake '
      'server',
      () async {
        h.connectivity.online = false;
        final land = _unwrapLand(
          await h.repo.addLand(_domainLand(name: 'Offline Land')),
        );
        expect(await h.outbox.peekAll(), hasLength(1));

        h.connectivity.online = true;
        await h.engine.syncNow();

        expect(await h.outbox.peekAll(), isEmpty);
        expect(h.remote.allRows, hasLength(1));
        expect(h.remote.allRows.single.name, 'Offline Land');

        final localRow = await h.local.getByClientUuid(land.id);
        expect(localRow, isNotNull);
        expect(localRow!.id, isNotEmpty, reason: 'server id reconciled');
        expect(localRow.pending, isFalse);
      },
    );

    test(
      '(c) editing an already-synced row while offline stages the edit and '
      'syncs it on reconnect',
      () async {
        final land = _unwrapLand(
          await h.repo.addLand(_domainLand(name: 'Original')),
        );
        h.connectivity.online = true;
        await h.engine.syncNow();
        final synced = await h.local.getByClientUuid(land.id);
        expect(synced!.id, isNotEmpty);

        h.connectivity.online = false;
        await h.repo.updateLand(
          Land(
            id: land.id,
            userId: land.userId,
            name: 'Edited Offline',
            createdAt: land.createdAt,
            updatedAt: DateTime.now(),
          ),
        );

        final pendingRow = await h.local.getByClientUuid(land.id);
        expect(pendingRow!.name, 'Edited Offline');
        expect(pendingRow.pending, isTrue);
        expect(h.remote.updateCalls, isEmpty);
        final outboxRows = await h.outbox.peekAll();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.op, 'update');

        h.connectivity.online = true;
        await h.engine.syncNow();

        expect(await h.outbox.peekAll(), isEmpty);
        expect(h.remote.allRows.single.name, 'Edited Offline');
        final finalRow = await h.local.getByClientUuid(land.id);
        expect(finalRow!.pending, isFalse);
      },
    );

    test(
      '(d) deleting an already-synced row while offline tombstones it '
      'locally (nothing sent), then syncs the delete on reconnect',
      () async {
        final land = _unwrapLand(
          await h.repo.addLand(_domainLand(name: 'To Delete')),
        );
        h.connectivity.online = true;
        await h.engine.syncNow();
        final synced = await h.local.getByClientUuid(land.id);
        final serverId = synced!.id;
        expect(serverId, isNotEmpty);

        h.connectivity.online = false;
        await h.repo.deleteLand(land.id);

        // Tombstoned locally (still visible to getByClientUuid, which
        // includes tombstones), nothing sent yet.
        expect(await h.local.getByClientUuid(land.id), isNotNull);
        expect(h.remote.deleteCalls, isEmpty);
        expect(
          h.remote.allRows,
          hasLength(1),
          reason: 'the fake server copy is untouched while offline',
        );
        final outboxRows = await h.outbox.peekAll();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.op, 'delete');

        h.connectivity.online = true;
        await h.engine.syncNow();

        expect(await h.outbox.peekAll(), isEmpty);
        expect(h.remote.deleteCalls, [serverId]);
        expect(h.remote.allRows, isEmpty);
        expect(await h.local.getByClientUuid(land.id), isNull);
      },
    );

    test(
      '(e) a pull applies a server-side change into the local mirror',
      () async {
        await h.local.upsert(
          _land(
            clientUuid: 'cu-pull',
            id: 'srv-pull',
            name: 'Old name',
            updatedAt: DateTime.utc(2026),
          ),
          pending: false,
        );
        h.remote.seedServerRow(
          _land(
            clientUuid: 'cu-pull',
            id: 'srv-pull',
            name: 'New name from server',
            updatedAt: DateTime.utc(2026, 6),
          ),
        );

        h.connectivity.online = true;
        await h.engine.syncNow();

        final row = await h.local.getByClientUuid('cu-pull');
        expect(row!.name, 'New name from server');
        expect(row.pending, isFalse);
      },
    );

    test(
      '(f) LWW conflict: a newer local pending edit beats a stale server '
      'row, and a newer server row beats a stale local pending edit',
      () async {
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

        h.connectivity.online = true;
        await h.engine.syncNow();

        final localWinsRow = await h.local.getByClientUuid(
          'cu-lww-local-wins',
        );
        expect(localWinsRow!.name, 'Local newer edit');
        expect(localWinsRow.pending, isTrue);

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
        expect(serverWinsRow!.name, 'Server newer value');
        expect(serverWinsRow.pending, isFalse);
      },
    );
  });

  group('season (FK child) — airplane mode matrix', () {
    late _SeasonHarness h;

    setUp(() {
      h = _SeasonHarness();
      OfflineConfig.enabled = true;
    });

    tearDown(() async {
      OfflineConfig.enabled = false;
      await h.dispose();
    });

    test(
      '(a) create while offline stages the row locally and queues it in the '
      'outbox; nothing is sent',
      () async {
        h.connectivity.online = false;

        final season = _unwrapSeason(
          await h.repo.addSeason(_domainSeason(name: 'Offline Season')),
        );

        final localRow = await h.local.getByClientUuid(season.id);
        expect(localRow, isNotNull);
        expect(localRow!.pending, isTrue);
        expect(localRow.id, isEmpty, reason: 'no server id yet');

        final pendingRows = await h.outbox.peekAll();
        expect(pendingRows, hasLength(1));
        expect(pendingRows.single.clientUuid, season.id);
        expect(pendingRows.single.op, 'create');

        expect(h.remote.addCalls, isEmpty);
        expect(h.remote.allRows, isEmpty);
      },
    );

    test(
      '(b) reconnecting and syncing sends the queued create to the fake '
      'server',
      () async {
        h.connectivity.online = false;
        final season = _unwrapSeason(
          await h.repo.addSeason(_domainSeason(name: 'Offline Season')),
        );
        expect(await h.outbox.peekAll(), hasLength(1));

        h.connectivity.online = true;
        await h.engine.syncNow();

        expect(await h.outbox.peekAll(), isEmpty);
        expect(h.remote.allRows, hasLength(1));
        expect(h.remote.allRows.single.name, 'Offline Season');

        final localRow = await h.local.getByClientUuid(season.id);
        expect(localRow, isNotNull);
        expect(localRow!.id, isNotEmpty, reason: 'server id reconciled');
        expect(localRow.pending, isFalse);
      },
    );

    test(
      '(c) editing an already-synced row while offline stages the edit and '
      'syncs it on reconnect',
      () async {
        final season = _unwrapSeason(
          await h.repo.addSeason(_domainSeason(name: 'Original')),
        );
        h.connectivity.online = true;
        await h.engine.syncNow();
        final synced = await h.local.getByClientUuid(season.id);
        expect(synced!.id, isNotEmpty);

        h.connectivity.online = false;
        await h.repo.updateSeason(
          Season(
            id: season.id,
            userId: season.userId,
            name: 'Edited Offline',
            plantId: season.plantId,
            landId: season.landId,
            startDate: season.startDate,
            createdAt: season.createdAt,
            updatedAt: DateTime.now(),
          ),
        );

        final pendingRow = await h.local.getByClientUuid(season.id);
        expect(pendingRow!.name, 'Edited Offline');
        expect(pendingRow.pending, isTrue);
        expect(h.remote.updateCalls, isEmpty);
        final outboxRows = await h.outbox.peekAll();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.op, 'update');

        h.connectivity.online = true;
        await h.engine.syncNow();

        expect(await h.outbox.peekAll(), isEmpty);
        expect(h.remote.allRows.single.name, 'Edited Offline');
        final finalRow = await h.local.getByClientUuid(season.id);
        expect(finalRow!.pending, isFalse);
      },
    );

    test(
      '(d) deleting an already-synced row while offline tombstones it '
      'locally (nothing sent), then syncs the delete on reconnect',
      () async {
        final season = _unwrapSeason(
          await h.repo.addSeason(_domainSeason(name: 'To Delete')),
        );
        h.connectivity.online = true;
        await h.engine.syncNow();
        final synced = await h.local.getByClientUuid(season.id);
        final serverId = synced!.id;
        expect(serverId, isNotEmpty);

        h.connectivity.online = false;
        await h.repo.deleteSeason(season.id);

        expect(await h.local.getByClientUuid(season.id), isNotNull);
        expect(h.remote.deleteCalls, isEmpty);
        expect(
          h.remote.allRows,
          hasLength(1),
          reason: 'the fake server copy is untouched while offline',
        );
        final outboxRows = await h.outbox.peekAll();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.op, 'delete');

        h.connectivity.online = true;
        await h.engine.syncNow();

        expect(await h.outbox.peekAll(), isEmpty);
        expect(h.remote.deleteCalls, [serverId]);
        expect(h.remote.allRows, isEmpty);
        expect(await h.local.getByClientUuid(season.id), isNull);
      },
    );

    test(
      '(e) a pull applies a server-side change into the local mirror',
      () async {
        await h.local.upsert(
          _season(
            clientUuid: 'cu-pull',
            id: 'srv-pull',
            name: 'Old name',
            updatedAt: DateTime.utc(2026),
          ),
          pending: false,
        );
        h.remote.seedServerRow(
          _season(
            clientUuid: 'cu-pull',
            id: 'srv-pull',
            name: 'New name from server',
            updatedAt: DateTime.utc(2026, 6),
          ),
        );

        h.connectivity.online = true;
        await h.engine.syncNow();

        final row = await h.local.getByClientUuid('cu-pull');
        expect(row!.name, 'New name from server');
        expect(row.pending, isFalse);
      },
    );

    test(
      '(f) LWW conflict: a newer local pending edit beats a stale server '
      'row, and a newer server row beats a stale local pending edit',
      () async {
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

        h.connectivity.online = true;
        await h.engine.syncNow();

        final localWinsRow = await h.local.getByClientUuid(
          'cu-lww-local-wins',
        );
        expect(localWinsRow!.name, 'Local newer edit');
        expect(localWinsRow.pending, isTrue);

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
        expect(serverWinsRow!.name, 'Server newer value');
        expect(serverWinsRow.pending, isFalse);
      },
    );
  });
}
