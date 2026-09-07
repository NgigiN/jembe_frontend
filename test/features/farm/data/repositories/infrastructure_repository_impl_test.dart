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
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/infrastructure_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/infrastructure_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInfrastructureRemoteDataSource
    implements InfrastructureRemoteDataSource {
  InfrastructureModel? lastAdded;
  InfrastructureModel? lastUpdated;
  final List<String> deleteCalls = [];
  List<InfrastructureModel> getInfrastructuresResult = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<InfrastructureModel>> getInfrastructures({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    return getInfrastructuresResult;
  }

  @override
  Future<InfrastructureModel> addInfrastructure(
    InfrastructureModel infrastructure,
  ) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = infrastructure;
    return infrastructure;
  }

  @override
  Future<InfrastructureModel> updateInfrastructure(
    InfrastructureModel infrastructure,
  ) async {
    lastUpdated = infrastructure;
    return infrastructure;
  }

  @override
  Future<void> deleteInfrastructure(String id) async {
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

InfrastructureModel _infrastructure({
  required String clientUuid,
  String id = '',
  String type = 'Barn',
  String name = 'Main Barn',
  String notes = '',
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return InfrastructureModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    type: type,
    name: name,
    location: 'North Field',
    cost: 1000,
    date: date ?? at,
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
      'addInfrastructure builds a fresh InfrastructureModel from the '
      'primitive args, defaulting a null notes to the empty string, and '
      'sends it to the data source',
      () async {
        final dataSource = FakeInfrastructureRemoteDataSource();
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: dataSource,
        );
        final date = DateTime.utc(2026, 3);

        await repository.addInfrastructure(
          'Barn',
          'Main Barn',
          'North Field',
          1000,
          date,
          'user-1',
          null,
        );

        expect(dataSource.lastAdded?.name, 'Main Barn');
        expect(dataSource.lastAdded?.type, 'Barn');
        expect(
          dataSource.lastAdded?.notes,
          '',
          reason: 'notes is non-nullable on the domain model',
        );
        expect(dataSource.lastAdded?.id, '');
      },
    );

    test(
      'updateInfrastructure fetches the existing rows, then sends the '
      'updated model to the data source',
      () async {
        final dataSource = FakeInfrastructureRemoteDataSource()
          ..getInfrastructuresResult = [
            _infrastructure(clientUuid: '', id: 'infra-1', name: 'Old name'),
          ];
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: dataSource,
        );
        final date = DateTime.utc(2026, 3);

        await repository.updateInfrastructure(
          'infra-1',
          'Fence',
          'New name',
          'New Field',
          2000,
          date,
          null,
        );

        expect(dataSource.lastUpdated?.id, 'infra-1');
        expect(dataSource.lastUpdated?.name, 'New name');
        expect(
          dataSource.lastUpdated?.notes,
          '',
          reason: 'a null notes update still defaults to the empty string',
        );
      },
    );

    test(
      'watchInfrastructures does not crash and mirrors a single '
      'getInfrastructures snapshot',
      () async {
        final dataSource = FakeInfrastructureRemoteDataSource();
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final emission = await repository.watchInfrastructures().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test(
      'getInfrastructures: a NetworkException maps to NetworkFailure',
      () async {
        final dataSource = FakeInfrastructureRemoteDataSource()
          ..throwOnGet = NetworkException();
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.getInfrastructures();

        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'getInfrastructures: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeInfrastructureRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.getInfrastructures();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addInfrastructure: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeInfrastructureRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = InfrastructureRepositoryImpl(
        remoteDataSource: dataSource,
      );
      final date = DateTime.utc(2026, 3);

      final result = await repository.addInfrastructure(
        'Barn',
        'Main Barn',
        'North Field',
        1000,
        date,
        'user-1',
        null,
      );

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'addInfrastructure: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeInfrastructureRemoteDataSource()
          ..throwOnAdd = const ServerException('name is required');
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: dataSource,
        );
        final date = DateTime.utc(2026, 3);

        final result = await repository.addInfrastructure(
          'Barn',
          'Main Barn',
          'North Field',
          1000,
          date,
          'user-1',
          null,
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

    test('a successful addInfrastructure maps to Right', () async {
      final dataSource = FakeInfrastructureRemoteDataSource();
      final repository = InfrastructureRepositoryImpl(
        remoteDataSource: dataSource,
      );
      final date = DateTime.utc(2026, 3);

      final result = await repository.addInfrastructure(
        'Barn',
        'Main Barn',
        'North Field',
        1000,
        date,
        'user-1',
        null,
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late InfrastructureLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeInfrastructureRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = InfrastructureLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeInfrastructureRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addInfrastructure upserts a local pending row with a minted '
      'clientUuid, enqueues a create intent, and never calls remote',
      () async {
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final date = DateTime.utc(2026, 3);

        final result = await repository.addInfrastructure(
          'Barn',
          'Main Barn',
          'North Field',
          1000,
          date,
          'user-1',
          'Freshly built',
        );

        expect(remote.lastAdded, isNull);

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (item) => expect(item.id, 'cu-new-1'),
        );

        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'Main Barn');
        expect(row.notes, 'Freshly built');

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'infrastructure');
        expect(rows.single.clientUuid, 'cu-new-1');

        // notes IS sent on the wire — it's a non-nullable field.
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['notes'], 'Freshly built');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateInfrastructure upserts (pending) and enqueues an update, '
      'preserving the existing serverId',
      () async {
        await local.upsert(
          _infrastructure(
            clientUuid: 'cu-existing',
            id: 'server-42',
            name: 'Old Name',
          ),
          pending: false,
        );

        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );
        final date = DateTime.utc(2026, 3);

        final result = await repository.updateInfrastructure(
          'cu-existing',
          'Fence',
          'New Name',
          'New Field',
          2000,
          date,
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
      'updateInfrastructure on a missing clientUuid returns CacheFailure',
      () async {
        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateInfrastructure(
          'cu-missing',
          'Barn',
          'X',
          'Field',
          100,
          DateTime.utc(2026),
          null,
        );

        expect(result.isLeft(), isTrue);
      },
    );

    test(
      'deleteInfrastructure marks the local row deleted and enqueues a '
      'delete intent',
      () async {
        await local.upsert(
          _infrastructure(clientUuid: 'cu-doomed'),
          pending: false,
        );

        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteInfrastructure('cu-doomed');

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
      'watchInfrastructures emits domain Infrastructures whose id equals '
      'the row clientUuid',
      () async {
        await local.upsert(
          _infrastructure(clientUuid: 'cu-watch-1', name: 'Watched Barn'),
          pending: false,
        );

        final repository = InfrastructureRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchInfrastructures().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Barn');
      },
    );
  });

  group('InfrastructureModel wire body (byte-for-byte field set)', () {
    test('toJson sends notes (non-nullable) plus the rest of the body', () {
      final infra = _infrastructure(
        clientUuid: 'cu-1',
        type: 'Barn',
        name: 'Main Barn',
        notes: 'Some notes',
        date: DateTime.utc(2026, 3, 1),
      );

      expect(infra.toJson(), {
        'type': 'Barn',
        'name': 'Main Barn',
        'location': 'North Field',
        'cost': 1000.0,
        'date': DateTime.utc(2026, 3, 1).toIso8601String(),
        'notes': 'Some notes',
      });
    });
  });
}
