import 'dart:convert';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/land_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLandRemoteDataSource implements LandRemoteDataSource {
  LandModel? lastAdded;
  LandModel? lastUpdated;
  final List<String> deleteCalls = [];

  @override
  Future<List<LandModel>> getLands({DateTime? updatedSince}) async => [];

  @override
  Future<LandModel> addLand(LandModel land) async {
    lastAdded = land;
    return land;
  }

  @override
  Future<LandModel> updateLand(LandModel land) async {
    lastUpdated = land;
    return land;
  }

  @override
  Future<void> deleteLand(String id) async {
    deleteCalls.add(id);
  }
}

/// Deterministic [UuidGen] fake — mirrors the one in `land_model_test.dart`.
class _FixedUuidGen extends UuidGen {
  const _FixedUuidGen(this.value);
  final String value;

  @override
  String v4() => value;
}

/// No-op [SyncEngine] fake: records how many times [syncNow] was fired
/// (fire-and-forget from the repository) without doing any real sync work
/// or requiring the engine's full outbox/cursors/connectivity dependency
/// graph.
class _FakeSyncEngine implements SyncEngine {
  int syncNowCalls = 0;

  @override
  Future<void> syncNow() async {
    syncNowCalls++;
  }

  @override
  Stream<SyncStatus> get statusStream => const Stream.empty();

  @override
  SyncStatus get status => const SyncStatus(phase: SyncPhase.idle);

  @override
  void start() {}

  @override
  void dispose() {}
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

void main() {
  // Every test that flips the flag on must not leak it into the next test.
  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's live-HTTP behavior, unchanged)", () {
    test(
      'addLand carries tenureType from the Land entity into the model sent to the data source',
      () async {
        final dataSource = FakeLandRemoteDataSource();
        final repository = LandRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.addLand(
          Land(
            id: '',
            userId: 'user-1',
            name: 'North Field',
            tenureType: 'rented',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.tenureType, 'rented');
      },
    );

    test(
      'updateLand carries tenureType from the Land entity into the model sent to the data source',
      () async {
        final dataSource = FakeLandRemoteDataSource();
        final repository = LandRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.updateLand(
          Land(
            id: 'land-1',
            userId: 'user-1',
            name: 'North Field',
            tenureType: 'owned',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.tenureType, 'owned');
      },
    );

    test(
      'watchLands does not crash and mirrors a single getLands snapshot',
      () async {
        final dataSource = FakeLandRemoteDataSource();
        final repository = LandRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchLands().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late LandLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeLandRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = LandLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeLandRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addLand upserts a local pending row with a minted clientUuid, enqueues a create intent, and never calls remote',
      () async {
        final repository = LandRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addLand(
          Land(
            id: '',
            userId: 'user-1',
            name: 'North Field',
            tenureType: 'rented',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Never touched the network.
        expect(remote.lastAdded, isNull);

        // Returns Right with id == the minted clientUuid.
        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (land) => expect(land.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'North Field');
        expect(row.tenureType, 'rented');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'land');
        expect(rows.single.clientUuid, 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateLand upserts (pending) and enqueues an update, preserving the existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _land(clientUuid: 'cu-existing', id: 'server-42', name: 'Old Name'),
          pending: false,
        );

        final repository = LandRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateLand(
          Land(
            id: 'cu-existing', // presentation id == clientUuid
            userId: 'user-1',
            name: 'New Name',
            tenureType: 'owned',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );

        expect(remote.lastUpdated, isNull);
        expect(result.isRight(), isTrue);

        final row = await local.getByClientUuid('cu-existing');
        expect(row, isNotNull);
        expect(
          row!.id,
          'server-42',
          reason: 'the existing serverId must be preserved',
        );
        expect(row.name, 'New Name');
        expect(row.tenureType, 'owned');
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['id'], 'server-42');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'deleteLand marks the local row deleted and enqueues a delete intent',
      () async {
        await local.upsert(_land(clientUuid: 'cu-doomed'), pending: false);

        final repository = LandRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteLand('cu-doomed');

        expect(remote.deleteCalls, isEmpty);
        expect(result.isRight(), isTrue);

        final row = await local.getByClientUuid('cu-doomed');
        expect(row, isNotNull);
        expect(row!.deletedLocally, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'delete');
        expect(rows.single.clientUuid, 'cu-doomed');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'watchLands emits domain Lands whose id equals the row clientUuid',
      () async {
        await local.upsert(
          _land(clientUuid: 'cu-watch-1', name: 'Watched Field'),
          pending: false,
        );

        final repository = LandRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchLands().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Field');
      },
    );

    test(
      'getLands (one-shot) returns local rows presented with clientUuid as id',
      () async {
        await local.upsert(_land(clientUuid: 'cu-get-1'), pending: false);

        final repository = LandRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getLands();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (lands) {
          expect(lands, hasLength(1));
          expect(lands.single.id, 'cu-get-1');
        });
      },
    );
  });
}
