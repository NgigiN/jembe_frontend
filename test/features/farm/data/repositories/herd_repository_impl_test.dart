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
import 'package:farm_tracker/features/farm/data/datasources/herd_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/herd_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHerdRemoteDataSource implements HerdRemoteDataSource {
  HerdModel? lastAdded;
  HerdModel? lastUpdated;
  final List<String> deleteCalls = [];
  List<HerdModel> getHerdsResult = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<HerdModel>> getHerds({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    return getHerdsResult;
  }

  @override
  Future<HerdModel> addHerd(HerdModel herd) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = herd;
    return herd;
  }

  @override
  Future<HerdModel> updateHerd(HerdModel herd) async {
    lastUpdated = herd;
    return herd;
  }

  @override
  Future<void> deleteHerd(String id) async {
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

HerdModel _herd({
  required String clientUuid,
  String id = '',
  String name = 'North Herd',
  String animalTypeId = 'server-type-1',
  int initialHeadCount = 10,
  int? currentHeadCount,
  DateTime? startDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return HerdModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    animalTypeId: animalTypeId,
    location: 'North Field',
    initialHeadCount: initialHeadCount,
    currentHeadCount: currentHeadCount ?? initialHeadCount,
    startDate: startDate ?? at,
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
      'addHerd builds a fresh HerdModel from the primitive args and sends '
      'it to the data source',
      () async {
        final dataSource = FakeHerdRemoteDataSource();
        final repository = HerdRepositoryImpl(remoteDataSource: dataSource);
        final startDate = DateTime.utc(2026, 3);

        await repository.addHerd(
          'North Herd',
          'server-type-1',
          'North Field',
          'user-1',
          10,
          startDate: startDate,
        );

        expect(dataSource.lastAdded?.name, 'North Herd');
        expect(dataSource.lastAdded?.animalTypeId, 'server-type-1');
        expect(dataSource.lastAdded?.initialHeadCount, 10);
        expect(dataSource.lastAdded?.currentHeadCount, 10);
        expect(dataSource.lastAdded?.id, '');
      },
    );

    test(
      'updateHerd fetches the existing rows, then sends the updated model '
      'to the data source, preserving currentHeadCount',
      () async {
        final dataSource = FakeHerdRemoteDataSource()
          ..getHerdsResult = [
            _herd(
              clientUuid: '',
              id: 'herd-1',
              name: 'Old name',
              currentHeadCount: 7,
            ),
          ];
        final repository = HerdRepositoryImpl(remoteDataSource: dataSource);
        final startDate = DateTime.utc(2026, 3);

        await repository.updateHerd(
          'herd-1',
          'New name',
          'server-type-2',
          'New Field',
          15,
          startDate: startDate,
        );

        expect(dataSource.lastUpdated?.id, 'herd-1');
        expect(dataSource.lastUpdated?.name, 'New name');
        expect(dataSource.lastUpdated?.initialHeadCount, 15);
        expect(
          dataSource.lastUpdated?.currentHeadCount,
          7,
          reason: 'server-managed currentHeadCount is preserved, not the '
              'new initialHeadCount',
        );
      },
    );

    test(
      'watchHerds does not crash and mirrors a single getHerds snapshot',
      () async {
        final dataSource = FakeHerdRemoteDataSource();
        final repository = HerdRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchHerds().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getHerds: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeHerdRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = HerdRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getHerds();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getHerds: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeHerdRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = HerdRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getHerds();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addHerd: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeHerdRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = HerdRepositoryImpl(remoteDataSource: dataSource);
      final startDate = DateTime.utc(2026, 3);

      final result = await repository.addHerd(
        'North Herd',
        'server-type-1',
        'North Field',
        'user-1',
        10,
        startDate: startDate,
      );

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'addHerd: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeHerdRemoteDataSource()
          ..throwOnAdd = const ServerException('name is required');
        final repository = HerdRepositoryImpl(remoteDataSource: dataSource);
        final startDate = DateTime.utc(2026, 3);

        final result = await repository.addHerd(
          'North Herd',
          'server-type-1',
          'North Field',
          'user-1',
          10,
          startDate: startDate,
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

    test('a successful addHerd maps to Right', () async {
      final dataSource = FakeHerdRemoteDataSource();
      final repository = HerdRepositoryImpl(remoteDataSource: dataSource);
      final startDate = DateTime.utc(2026, 3);

      final result = await repository.addHerd(
        'North Herd',
        'server-type-1',
        'North Field',
        'user-1',
        10,
        startDate: startDate,
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late HerdLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeHerdRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = HerdLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeHerdRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addHerd upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = HerdRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final startDate = DateTime.utc(2026, 3);

        final result = await repository.addHerd(
          'North Herd',
          'server-type-1',
          'North Field',
          'user-1',
          10,
          startDate: startDate,
        );

        expect(remote.lastAdded, isNull);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (herd) => expect(herd.id, 'cu-new-1'),
        );

        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'North Herd');
        expect(row.initialHeadCount, 10);
        expect(
          row.currentHeadCount,
          10,
          reason: 'currentHeadCount is initialized to initialHeadCount on '
              'create, tracked locally even though the wire body omits it',
        );

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'herd');
        expect(rows.single.clientUuid, 'cu-new-1');

        // The staged payload (what gets pushed to the server) must NOT
        // contain current_head_count — it's server-managed.
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload.containsKey('current_head_count'), isFalse);

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateHerd upserts (pending) and enqueues an update, preserving the '
      'existing serverId and currentHeadCount',
      () async {
        await local.upsert(
          _herd(
            clientUuid: 'cu-existing',
            id: 'server-42',
            name: 'Old Name',
            currentHeadCount: 8,
          ),
          pending: false,
        );

        final repository = HerdRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );
        final startDate = DateTime.utc(2026, 3);

        final result = await repository.updateHerd(
          'cu-existing',
          'New Name',
          'server-type-2',
          'New Field',
          20,
          startDate: startDate,
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
        expect(row.initialHeadCount, 20);
        expect(
          row.currentHeadCount,
          8,
          reason: 'currentHeadCount is server-managed and preserved',
        );
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');

        expect(sync.syncNowCalls, 1);
      },
    );

    test('updateHerd on a missing clientUuid returns CacheFailure', () async {
      final repository = HerdRepositoryImpl(
        remoteDataSource: remote,
        local: local,
        outbox: outbox,
        sync: sync,
      );

      final result = await repository.updateHerd(
        'cu-missing',
        'X',
        'server-type-1',
        'Field',
        1,
        startDate: DateTime.utc(2026),
      );

      expect(result.isLeft(), isTrue);
    });

    test(
      'deleteHerd marks the local row deleted and enqueues a delete intent',
      () async {
        await local.upsert(_herd(clientUuid: 'cu-doomed'), pending: false);

        final repository = HerdRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteHerd('cu-doomed');

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
      'watchHerds emits domain Herds whose id equals the row clientUuid',
      () async {
        await local.upsert(
          _herd(clientUuid: 'cu-watch-1', name: 'Watched Herd'),
          pending: false,
        );

        final repository = HerdRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchHerds().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Herd');
      },
    );
  });

  group('HerdModel wire body (byte-for-byte field set)', () {
    test(
      'toJson OMITS current_head_count (server-managed) and sends the '
      'rest of the pre-offline body',
      () {
        final herd = _herd(
          clientUuid: 'cu-1',
          name: 'North Herd',
          animalTypeId: 'server-type-1',
          initialHeadCount: 10,
          currentHeadCount: 7,
          startDate: DateTime.utc(2026, 3, 1),
        );

        expect(herd.toJson(), {
          'name': 'North Herd',
          'animal_type_id': 'server-type-1',
          'location': 'North Field',
          'initial_head_count': 10,
          'start_date': DateTime.utc(2026, 3, 1).toIso8601String(),
          'end_date': null,
        });
      },
    );
  });
}
