// Golden end-to-end test for the offline-first animal_type pipeline (Task
// 8a — see
// `.superpowers/sdd/2026-09-05-offline-first-p3-frontend-entity-rollout/task-8-brief.md`).
//
// Mirrors `test/core/sync/harvest_offline_e2e_test.dart`: wires the REAL
// collaborators together — a real `AppDatabase.forTesting` (in-memory
// sqlite via drift), real `OutboxDao`/`SyncCursorDao`/
// `AnimalTypeLocalDataSource`, a real `AnimalTypeSyncer` and a real
// `SyncEngine`, driven through a real `AnimalTypeRepositoryImpl` — and
// proves the whole loop converges against a fake in-memory "server". Only
// the network boundary (`AnimalTypeRemoteDataSource`, `DeletionsApplier`)
// and the OS connectivity signal are faked.
//
// `animal_type` is a FK-free root entity (unlike harvest's parent-season
// FK), so every create here is unconditionally in scope for P3.
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
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_type_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/animal_type_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `animal_type` entity.
///
/// Mirrors the P1 REST semantics this pilot targets: `addAnimalType` mints
/// a server id and is idempotent on `client_uuid`; `getAnimalTypes
/// (updatedSince:)` returns rows whose `updatedAt >= updatedSince` (or
/// every row when null) — the sync pull always calls it this way.
/// [seedServerRow] lets a test inject a server-side row directly — e.g. to
/// simulate a change made from another device.
class _FakeAnimalTypeRemoteDataSource implements AnimalTypeRemoteDataSource {
  final Map<String, AnimalTypeModel> _byServerId = <String, AnimalTypeModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  /// Every `client_uuid` [addAnimalType] was ever called with, in call
  /// order.
  final List<String> addAnimalTypeClientUuids = <String>[];

  /// Every row currently held by the fake server.
  List<AnimalTypeModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType) async {
    addAnimalTypeClientUuids.add(animalType.clientUuid);
    final existingServerId = _serverIdByClientUuid[animalType.clientUuid];
    if (existingServerId != null) {
      // Idempotent replay: same clientUuid comes back as the SAME row.
      return _byServerId[existingServerId]!;
    }

    final serverId = '${_nextId++}';
    final stored = AnimalTypeModel(
      id: serverId,
      clientUuid: animalType.clientUuid,
      userId: animalType.userId,
      name: animalType.name,
      notes: animalType.notes,
      createdAt: animalType.createdAt,
      updatedAt: animalType.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[animalType.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType) async {
    final existing = _byServerId[animalType.id];
    final stored = AnimalTypeModel(
      id: animalType.id,
      clientUuid: existing?.clientUuid ?? animalType.clientUuid,
      userId: animalType.userId,
      name: animalType.name,
      notes: animalType.notes,
      createdAt: existing?.createdAt ?? animalType.createdAt,
      updatedAt: animalType.updatedAt,
    );
    _byServerId[animalType.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteAnimalType(String id) async {
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<List<AnimalTypeModel>> getAnimalTypes({DateTime? updatedSince}) async {
    Iterable<AnimalTypeModel> rows = _byServerId.values;
    if (updatedSince != null) {
      rows = rows.where((row) => !row.updatedAt.isBefore(updatedSince));
    }
    return rows.toList();
  }

  @override
  Future<AnimalTypeModel> getAnimalType(String id) async => _byServerId[id]!;

  /// Test-only: injects/replaces a server-side row directly, bypassing
  /// [addAnimalType] — simulates an inbound change from another device.
  void seedServerRow(AnimalTypeModel row) {
    _byServerId[row.id] = row;
    if (row.clientUuid.isNotEmpty) {
      _serverIdByClientUuid[row.clientUuid] = row.id;
    }
  }
}

/// Fake `/sync/deletions` applier: a test [addTombstone]s a `clientUuid`
/// and the next [applyDeletions] hard-deletes that row locally.
class _FakeDeletionsApplier implements DeletionsApplier {
  _FakeDeletionsApplier(this._local);

  final AnimalTypeLocalDataSource _local;
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
    local = AnimalTypeLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeAnimalTypeRemoteDataSource();
    deletions = _FakeDeletionsApplier(local);
    connectivity = _FakeConnectivityService();
    final syncer = AnimalTypeSyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
    );
    repo = AnimalTypeRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final AnimalTypeLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeAnimalTypeRemoteDataSource remote;
  late final _FakeDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final AnimalTypeRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Builds an [AnimalTypeModel] for seeding the local mirror or the fake
/// server directly (bypassing the repository).
AnimalTypeModel _animalType({
  required String clientUuid,
  String id = '',
  String name = 'Cattle',
  String? notes,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return AnimalTypeModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    notes: notes,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
AnimalType _unwrap(Either<Failure, AnimalType> result) {
  return result.fold(
    (failure) => fail('expected Right, got $failure'),
    (type) => type,
  );
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
    'reconnect + syncNow converges: server has both animal types with the '
    'edit applied, local serverIds are populated, outbox is empty',
    () async {
      h.connectivity.online = false;

      final type1 = _unwrap(
        await h.repo.addAnimalType('Cattle', null, 'user-1'),
      );
      final type2 = _unwrap(
        await h.repo.addAnimalType('Goat', 'Meat breed', 'user-1'),
      );

      await h.repo.updateAnimalType(type2.id, 'Goat (renamed)', 'Meat breed');

      // --- Outbox coalesced BEFORE any sync attempt ---
      final pendingRows = await h.outbox.peekAll();
      expect(pendingRows.map((r) => r.clientUuid).toSet(), {
        type1.id,
        type2.id,
      });
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
      expect(serverNames[type1.id], 'Cattle');
      expect(serverNames[type2.id], 'Goat (renamed)');

      final local1 = await h.local.getByClientUuid(type1.id);
      final local2 = await h.local.getByClientUuid(type2.id);
      expect(local1, isNotNull);
      expect(local2, isNotNull);
      expect(local1!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2.name, 'Goat (renamed)');
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addAnimalType for the row',
    () async {
      h.connectivity.online = false;

      final ghost = _unwrap(
        await h.repo.addAnimalType('Ghost Type', null, 'user-1'),
      );
      await h.repo.deleteAnimalType(ghost.id);

      final rows = await h.outbox.peekAll();
      expect(rows.where((r) => r.clientUuid == ghost.id), isEmpty);
      expect(rows, isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addAnimalTypeClientUuids, isNot(contains(ghost.id)));
      expect(h.remote.allRows, isEmpty);

      final visible = await h.local.watchAnimalTypes().first;
      expect(visible, isEmpty);
    },
  );

  test(
    'inbound update: a newer server row overwrites the local mirror on '
    'pull',
    () async {
      await h.local.upsert(
        _animalType(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          name: 'Old name',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );

      h.remote.seedServerRow(
        _animalType(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          name: 'New name',
          updatedAt: DateTime.utc(2026, 6),
        ),
      );

      await h.engine.syncNow();

      final row = await h.local.getByClientUuid('cu-inbound-update');
      expect(row, isNotNull);
      expect(row!.name, 'New name');
      expect(row.pending, isFalse);
    },
  );

  test(
    'inbound tombstone: a server-reported deletion hard-deletes the local '
    'row, which then disappears from watchAnimalTypes',
    () async {
      await h.local.upsert(
        _animalType(clientUuid: 'cu-tombstoned', id: 'srv-2'),
        pending: false,
      );
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNotNull);

      h.deletions.addTombstone('cu-tombstoned');

      await h.engine.syncNow();

      expect(h.deletions.applyCount, 1);
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNull);

      final visible = await h.local.watchAnimalTypes().first;
      expect(visible.map((m) => m.clientUuid), isNot(contains('cu-tombstoned')));
    },
  );

  test(
    'LWW: a newer local pending edit beats a stale server row, and a newer '
    'server row beats a stale local pending edit',
    () async {
      // --- (a) local pending edit is NEWER than the server's row: local
      // wins. ---
      await h.local.upsert(
        _animalType(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'v1',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _animalType(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'v2',
          updatedAt: DateTime.utc(2026, 3),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _animalType(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          name: 'v3-server',
          updatedAt: DateTime.utc(2026, 2),
        ),
      );

      await h.engine.syncNow();

      final localWinsRow = await h.local.getByClientUuid(
        'cu-lww-local-wins',
      );
      expect(localWinsRow, isNotNull);
      expect(localWinsRow!.name, 'v2');
      expect(localWinsRow.pending, isTrue);

      // --- (b) server row is NEWER than the local pending edit: server
      // wins. ---
      await h.local.upsert(
        _animalType(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'v1',
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _animalType(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'v2',
          updatedAt: DateTime.utc(2026, 2),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _animalType(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          name: 'v4-server',
          updatedAt: DateTime.utc(2026, 4),
        ),
      );

      await h.engine.syncNow();

      final serverWinsRow = await h.local.getByClientUuid(
        'cu-lww-server-wins',
      );
      expect(serverWinsRow, isNotNull);
      expect(serverWinsRow!.name, 'v4-server');
      expect(serverWinsRow.pending, isFalse);
    },
  );
}
