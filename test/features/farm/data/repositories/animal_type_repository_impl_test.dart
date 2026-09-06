import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_type_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnimalTypeRemoteDataSource implements AnimalTypeRemoteDataSource {
  AnimalTypeModel? lastAdded;
  AnimalTypeModel? lastUpdated;
  final List<String> deleteCalls = [];
  AnimalTypeModel? getAnimalTypeResult;

  @override
  Future<List<AnimalTypeModel>> getAnimalTypes({DateTime? updatedSince}) async =>
      [];

  @override
  Future<AnimalTypeModel> getAnimalType(String id) async =>
      getAnimalTypeResult!;

  @override
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType) async {
    lastAdded = animalType;
    return animalType;
  }

  @override
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType) async {
    lastUpdated = animalType;
    return animalType;
  }

  @override
  Future<void> deleteAnimalType(String id) async {
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

void main() {
  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's live-HTTP behavior, unchanged)", () {
    test(
      'addAnimalType builds a fresh AnimalTypeModel from the primitive args '
      'and sends it to the data source',
      () async {
        final dataSource = FakeAnimalTypeRemoteDataSource();
        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: dataSource,
        );

        await repository.addAnimalType('Cattle', 'Dairy breed', 'user-1');

        expect(dataSource.lastAdded?.name, 'Cattle');
        expect(dataSource.lastAdded?.notes, 'Dairy breed');
        expect(dataSource.lastAdded?.userId, 'user-1');
        // Flag-off field set is byte-for-byte the original: id, userId,
        // name, notes, createdAt, updatedAt — no clientUuid populated
        // (defaults to '' and the wire body never carries it here; the
        // remote data source layer adds client_uuid to the HTTP request,
        // not this model-level check).
        expect(dataSource.lastAdded?.id, '');
      },
    );

    test(
      'updateAnimalType fetches the existing row, then sends the updated '
      'model to the data source',
      () async {
        final dataSource = FakeAnimalTypeRemoteDataSource()
          ..getAnimalTypeResult = _animalType(
            clientUuid: '',
            id: 'type-1',
            name: 'Old name',
          );
        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: dataSource,
        );

        await repository.updateAnimalType('type-1', 'New name', 'Updated');

        expect(dataSource.lastUpdated?.id, 'type-1');
        expect(dataSource.lastUpdated?.name, 'New name');
        expect(dataSource.lastUpdated?.notes, 'Updated');
      },
    );

    test(
      'watchAnimalTypes does not crash and mirrors a single getAnimalTypes '
      'snapshot',
      () async {
        final dataSource = FakeAnimalTypeRemoteDataSource();
        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final emission = await repository.watchAnimalTypes().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late AnimalTypeLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeAnimalTypeRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = AnimalTypeLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeAnimalTypeRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addAnimalType upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );

        final result = await repository.addAnimalType(
          'Cattle',
          'Dairy breed',
          'user-1',
        );

        expect(remote.lastAdded, isNull);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (type) => expect(type.id, 'cu-new-1'),
        );

        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'Cattle');
        expect(row.notes, 'Dairy breed');

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'animal_type');
        expect(rows.single.clientUuid, 'cu-new-1');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateAnimalType upserts (pending) and enqueues an update, '
      'preserving the existing serverId',
      () async {
        await local.upsert(
          _animalType(
            clientUuid: 'cu-existing',
            id: 'server-42',
            name: 'Old Name',
          ),
          pending: false,
        );

        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateAnimalType(
          'cu-existing',
          'New Name',
          'Updated notes',
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
        expect(row.notes, 'Updated notes');
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateAnimalType on a missing clientUuid returns CacheFailure',
      () async {
        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateAnimalType(
          'cu-missing',
          'X',
          null,
        );

        expect(result.isLeft(), isTrue);
      },
    );

    test(
      'deleteAnimalType marks the local row deleted and enqueues a delete '
      'intent',
      () async {
        await local.upsert(_animalType(clientUuid: 'cu-doomed'), pending: false);

        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteAnimalType('cu-doomed');

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
      'watchAnimalTypes emits domain AnimalTypes whose id equals the row '
      'clientUuid',
      () async {
        await local.upsert(
          _animalType(clientUuid: 'cu-watch-1', name: 'Watched Type'),
          pending: false,
        );

        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchAnimalTypes().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Type');
      },
    );

    test(
      'getAnimalTypes (one-shot) returns local rows presented with '
      'clientUuid as id',
      () async {
        await local.upsert(_animalType(clientUuid: 'cu-get-1'), pending: false);

        final repository = AnimalTypeRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getAnimalTypes();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          types,
        ) {
          expect(types, hasLength(1));
          expect(types.single.id, 'cu-get-1');
        });
      },
    );
  });

  group('AnimalTypeModel wire body (byte-for-byte field set)', () {
    test('toJson emits name and notes only, matching the pre-offline body', () {
      final withNotes = _animalType(
        clientUuid: 'cu-1',
        name: 'Goat',
        notes: 'Meat breed',
      );
      expect(withNotes.toJson(), {'name': 'Goat', 'notes': 'Meat breed'});

      final withoutNotes = _animalType(clientUuid: 'cu-2', name: 'Sheep');
      expect(withoutNotes.toJson(), {'name': 'Sheep'});
    });
  });
}
