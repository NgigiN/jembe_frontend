import 'dart:convert';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnimalRemoteDataSource implements AnimalRemoteDataSource {
  AnimalModel? lastAdded;
  AnimalModel? lastUpdated;
  final List<String> deleteCalls = [];

  @override
  Future<List<AnimalModel>> getAnimals({DateTime? updatedSince}) async => [];

  @override
  Future<AnimalModel> addAnimal(AnimalModel animal) async {
    lastAdded = animal;
    return animal;
  }

  @override
  Future<AnimalModel> updateAnimal(AnimalModel animal) async {
    lastUpdated = animal;
    return animal;
  }

  @override
  Future<void> deleteAnimal(String id) async {
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

final birthDate = DateTime(2024);

AnimalModel _animal({
  required String clientUuid,
  String id = '',
  String name = 'Bessie',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return AnimalModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    animalTypeId: 'type-1',
    herdId: 'herd-1',
    birthDate: birthDate,
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
      'addAnimal carries sex and acquisitionSource from the Animal entity into the model sent to the data source',
      () async {
        final dataSource = FakeAnimalRemoteDataSource();
        final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.addAnimal(
          Animal(
            id: '',
            userId: 'user-1',
            name: 'Bessie',
            animalTypeId: 'type-1',
            herdId: 'herd-1',
            birthDate: birthDate,
            sex: 'female',
            acquisitionSource: 'bought',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.sex, 'female');
        expect(dataSource.lastAdded?.acquisitionSource, 'bought');
      },
    );

    test(
      'updateAnimal carries sex and acquisitionSource from the Animal entity into the model sent to the data source',
      () async {
        final dataSource = FakeAnimalRemoteDataSource();
        final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.updateAnimal(
          Animal(
            id: 'animal-1',
            userId: 'user-1',
            name: 'Bessie',
            animalTypeId: 'type-1',
            herdId: 'herd-1',
            birthDate: birthDate,
            sex: 'male',
            acquisitionSource: 'gift',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.sex, 'male');
        expect(dataSource.lastUpdated?.acquisitionSource, 'gift');
      },
    );

    test(
      'watchAnimals does not crash and mirrors a single getAnimals snapshot',
      () async {
        final dataSource = FakeAnimalRemoteDataSource();
        final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchAnimals().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late AnimalLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeAnimalRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = AnimalLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeAnimalRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addAnimal upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = AnimalRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addAnimal(
          Animal(
            id: '',
            userId: 'user-1',
            name: 'Bessie',
            animalTypeId: 'type-1',
            herdId: 'herd-1',
            birthDate: birthDate,
            sex: 'female',
            acquisitionSource: 'bought',
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
          (animal) => expect(animal.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'Bessie');
        expect(row.sex, 'female');
        expect(row.acquisitionSource, 'bought');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'animal');
        expect(rows.single.clientUuid, 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateAnimal upserts (pending) and enqueues an update, preserving the '
      'existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _animal(clientUuid: 'cu-existing', id: 'server-42', name: 'Old Name'),
          pending: false,
        );

        final repository = AnimalRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateAnimal(
          Animal(
            id: 'cu-existing', // presentation id == clientUuid
            userId: 'user-1',
            name: 'New Name',
            animalTypeId: 'type-1',
            herdId: 'herd-1',
            birthDate: birthDate,
            sex: 'male',
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
        expect(row.sex, 'male');
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['name'], 'New Name');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'deleteAnimal marks the local row deleted and enqueues a delete intent',
      () async {
        await local.upsert(_animal(clientUuid: 'cu-doomed'), pending: false);

        final repository = AnimalRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteAnimal('cu-doomed');

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
      'watchAnimals emits domain Animals whose id equals the row clientUuid',
      () async {
        await local.upsert(
          _animal(clientUuid: 'cu-watch-1', name: 'Watched Animal'),
          pending: false,
        );

        final repository = AnimalRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchAnimals().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Animal');
      },
    );

    test(
      'getAnimals (one-shot) returns local rows presented with clientUuid as '
      'id',
      () async {
        await local.upsert(_animal(clientUuid: 'cu-get-1'), pending: false);

        final repository = AnimalRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getAnimals();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          animals,
        ) {
          expect(animals, hasLength(1));
          expect(animals.single.id, 'cu-get-1');
        });
      },
    );
  });
}
