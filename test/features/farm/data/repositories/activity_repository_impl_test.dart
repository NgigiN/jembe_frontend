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
import 'package:farm_tracker/features/farm/data/datasources/activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/activity_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeActivityRemoteDataSource implements ActivityRemoteDataSource {
  ActivityModel? lastAdded;
  ActivityModel? lastUpdated;
  String? lastGetSourceType;
  int? lastGetCursor;
  List<ActivityModel> getResult = [];
  final List<String> deleteCalls = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<ActivityModel>> getActivities({
    String? sourceType,
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    lastGetSourceType = sourceType;
    lastGetCursor = cursor;
    return getResult;
  }

  @override
  Future<ActivityModel> addActivity(ActivityModel activity) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = activity;
    return activity;
  }

  @override
  Future<ActivityModel> updateActivity(ActivityModel activity) async {
    lastUpdated = activity;
    return activity;
  }

  @override
  Future<void> deleteActivity(String id) async {
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

ActivityModel _activity({
  required String clientUuid,
  String id = '',
  String sourceType = 'plant',
  String sourceId = 'season-1',
  int? animalId,
  String type = 'Weeding',
  String? details,
  double cost = 100,
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return ActivityModel(
    id: id,
    clientUuid: clientUuid,
    sourceType: sourceType,
    sourceId: sourceId,
    animalId: animalId,
    type: type,
    details: details,
    cost: cost,
    date: date ?? at,
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
      'addActivity carries fields from the Activity entity into the model '
      'sent to the data source',
      () async {
        final dataSource = FakeActivityRemoteDataSource();
        final repository = ActivityRepositoryImpl(
          remoteDataSource: dataSource,
        );
        final now = DateTime.now();

        await repository.addActivity(
          Activity(
            id: '',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Weeding',
            cost: 100,
            date: now,
            details: 'Cleared rows',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.cost, 100);
        expect(dataSource.lastAdded?.details, 'Cleared rows');
      },
    );

    test(
      'updateActivity carries fields from the Activity entity into the '
      'model sent to the data source',
      () async {
        final dataSource = FakeActivityRemoteDataSource();
        final repository = ActivityRepositoryImpl(
          remoteDataSource: dataSource,
        );
        final now = DateTime.now();

        await repository.updateActivity(
          Activity(
            id: 'activity-1',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Weeding',
            cost: 200,
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.cost, 200);
      },
    );

    test(
      'getActivities passes the sourceType filter straight through to the '
      'data source',
      () async {
        final dataSource = FakeActivityRemoteDataSource();
        final repository = ActivityRepositoryImpl(
          remoteDataSource: dataSource,
        );

        await repository.getActivities(sourceType: 'animal');

        expect(dataSource.lastGetSourceType, 'animal');
      },
    );

    test(
      'getActivities threads the pagination cursor to the data source on the '
      'online path (P3-02a)',
      () async {
        final dataSource = FakeActivityRemoteDataSource();
        final repository = ActivityRepositoryImpl(
          remoteDataSource: dataSource,
        );

        await repository.getActivities(cursor: 501);

        expect(dataSource.lastGetCursor, 501);
      },
    );

    test(
      'watchActivities does not crash and mirrors a single getActivities '
      'snapshot',
      () async {
        final dataSource = FakeActivityRemoteDataSource();
        final repository = ActivityRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final emission = await repository.watchActivities().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getActivities: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeActivityRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = ActivityRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getActivities();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getActivities: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeActivityRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = ActivityRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getActivities();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addActivity: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeActivityRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = ActivityRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addActivity(
        Activity(
          id: '',
          sourceType: 'plant',
          sourceId: 'season-1',
          type: 'Weeding',
          cost: 100,
          date: now,
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
      'addActivity: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeActivityRemoteDataSource()
          ..throwOnAdd = const ServerException('cost is required');
        final repository = ActivityRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        final result = await repository.addActivity(
          Activity(
            id: '',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Weeding',
            cost: 100,
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        result.fold(
          (failure) =>
              expect((failure as ServerFailure).message, 'cost is required'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('a successful addActivity maps to Right', () async {
      final dataSource = FakeActivityRemoteDataSource();
      final repository = ActivityRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addActivity(
        Activity(
          id: '',
          sourceType: 'plant',
          sourceId: 'season-1',
          type: 'Weeding',
          cost: 100,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late ActivityLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeActivityRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = ActivityLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeActivityRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addActivity upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = ActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addActivity(
          Activity(
            id: '',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Weeding',
            cost: 100,
            date: now,
            details: 'Cleared rows',
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
          (activity) => expect(activity.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.cost, 100);
        expect(row.details, 'Cleared rows');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'activity');
        expect(rows.single.clientUuid, 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateActivity upserts (pending) and enqueues an update, preserving '
      'the existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _activity(clientUuid: 'cu-existing', id: 'server-42', cost: 50),
          pending: false,
        );

        final repository = ActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateActivity(
          Activity(
            id: 'cu-existing', // presentation id == clientUuid
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Weeding',
            cost: 999,
            date: DateTime.utc(2026),
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
        expect(row.cost, 999);
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['cost'], 999);

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'deleteActivity marks the local row deleted and enqueues a delete '
      'intent',
      () async {
        await local.upsert(
          _activity(clientUuid: 'cu-doomed'),
          pending: false,
        );

        final repository = ActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteActivity('cu-doomed');

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
      'watchActivities emits domain Activities whose id equals the row '
      'clientUuid',
      () async {
        await local.upsert(
          _activity(clientUuid: 'cu-watch-1', cost: 77),
          pending: false,
        );

        final repository = ActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchActivities().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.cost, 77);
      },
    );

    test(
      'watchActivities(sourceType:) filters the local mirror to that '
      'source type only',
      () async {
        await local.upsert(
          _activity(clientUuid: 'cu-plant', sourceType: 'plant'),
          pending: false,
        );
        await local.upsert(
          _activity(clientUuid: 'cu-animal', sourceType: 'animal'),
          pending: false,
        );

        final repository = ActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission =
            await repository.watchActivities(sourceType: 'animal').first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-animal');
      },
    );

    test(
      'getActivities (one-shot) returns local rows presented with '
      'clientUuid as id',
      () async {
        await local.upsert(_activity(clientUuid: 'cu-get-1'), pending: false);

        final repository = ActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getActivities();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          activities,
        ) {
          expect(activities, hasLength(1));
          expect(activities.single.id, 'cu-get-1');
        });
      },
    );
  });
}
