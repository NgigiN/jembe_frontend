import 'dart:convert';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/plant_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePlantRemoteDataSource implements PlantRemoteDataSource {
  PlantModel? lastAdded;
  PlantModel? lastUpdated;
  final List<String> deleteCalls = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<PlantModel>> getPlants({DateTime? updatedSince}) async {
    if (throwOnGet != null) throw throwOnGet!;
    return [];
  }

  @override
  Future<PlantModel> addPlant(PlantModel plant) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = plant;
    return plant;
  }

  @override
  Future<PlantModel> updatePlant(PlantModel plant) async {
    lastUpdated = plant;
    return plant;
  }

  @override
  Future<void> deletePlant(String id) async {
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
/// (fire-and-forget from the repository) without doing any real sync work.
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

PlantModel _plant({
  required String clientUuid,
  String id = '',
  String name = 'Maize',
  String? variety,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return PlantModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    variety: variety,
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
      'addPlant carries variety from the Plant entity into the model sent '
      'to the data source',
      () async {
        final dataSource = FakePlantRemoteDataSource();
        final repository = PlantRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.addPlant(
          Plant(
            id: '',
            userId: 'user-1',
            name: 'Maize',
            variety: 'Hybrid 614',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.variety, 'Hybrid 614');
      },
    );

    test(
      'updatePlant carries variety from the Plant entity into the model '
      'sent to the data source',
      () async {
        final dataSource = FakePlantRemoteDataSource();
        final repository = PlantRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.updatePlant(
          Plant(
            id: 'plant-1',
            userId: 'user-1',
            name: 'Maize',
            variety: 'DK 8031',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.variety, 'DK 8031');
      },
    );

    test(
      'watchPlants does not crash and mirrors a single getPlants snapshot',
      () async {
        final dataSource = FakePlantRemoteDataSource();
        final repository = PlantRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchPlants().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getPlants: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakePlantRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = PlantRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getPlants();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getPlants: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakePlantRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = PlantRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getPlants();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addPlant: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakePlantRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = PlantRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addPlant(
        Plant(
          id: '',
          userId: 'user-1',
          name: 'Maize',
          createdAt: now,
          updatedAt: now,
        ),
      );

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'addPlant: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakePlantRemoteDataSource()
          ..throwOnAdd = const ServerException('name is required');
        final repository = PlantRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        final result = await repository.addPlant(
          Plant(
            id: '',
            userId: 'user-1',
            name: 'Maize',
            createdAt: now,
            updatedAt: now,
          ),
        );

        result.fold(
          (failure) => expect(
            (failure as ServerFailure).message,
            'name is required',
          ),
          (_) => fail('expected Left'),
        );
      },
    );

    test('a successful addPlant maps to Right', () async {
      final dataSource = FakePlantRemoteDataSource();
      final repository = PlantRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addPlant(
        Plant(
          id: '',
          userId: 'user-1',
          name: 'Maize',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late PlantLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakePlantRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = PlantLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakePlantRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addPlant upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = PlantRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addPlant(
          Plant(
            id: '',
            userId: 'user-1',
            name: 'Maize',
            variety: 'Hybrid 614',
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
          (plant) => expect(plant.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'Maize');
        expect(row.variety, 'Hybrid 614');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'plant');
        expect(rows.single.clientUuid, 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updatePlant upserts (pending) and enqueues an update, preserving the '
      'existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _plant(clientUuid: 'cu-existing', id: 'server-42', name: 'Old Name'),
          pending: false,
        );

        final repository = PlantRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updatePlant(
          Plant(
            id: 'cu-existing', // presentation id == clientUuid
            userId: 'user-1',
            name: 'New Name',
            variety: 'DK 8031',
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
        expect(row.variety, 'DK 8031');
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
      'deletePlant marks the local row deleted and enqueues a delete intent',
      () async {
        await local.upsert(_plant(clientUuid: 'cu-doomed'), pending: false);

        final repository = PlantRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deletePlant('cu-doomed');

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
      'watchPlants emits domain Plants whose id equals the row clientUuid',
      () async {
        await local.upsert(
          _plant(clientUuid: 'cu-watch-1', name: 'Watched Crop'),
          pending: false,
        );

        final repository = PlantRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchPlants().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Crop');
      },
    );

    test(
      'getPlants (one-shot) returns local rows presented with clientUuid as '
      'id',
      () async {
        await local.upsert(_plant(clientUuid: 'cu-get-1'), pending: false);

        final repository = PlantRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getPlants();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          plants,
        ) {
          expect(plants, hasLength(1));
          expect(plants.single.id, 'cu-get-1');
        });
      },
    );
  });
}
