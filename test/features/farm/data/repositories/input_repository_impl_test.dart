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
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/input_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInputRemoteDataSource implements InputRemoteDataSource {
  InputModel? lastAdded;
  InputModel? lastUpdated;
  String? lastGetSourceType;
  final List<String> deleteCalls = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<InputModel>> getInputs({
    String? sourceType,
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    lastGetSourceType = sourceType;
    return [];
  }

  @override
  Future<InputModel> addInput(InputModel input) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = input;
    return input;
  }

  @override
  Future<InputModel> updateInput(InputModel input) async {
    lastUpdated = input;
    return input;
  }

  @override
  Future<void> deleteInput(String id) async {
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

InputModel _input({
  required String clientUuid,
  String id = '',
  String sourceType = 'plant',
  String sourceId = 'season-1',
  int? animalId,
  String type = 'Fertilizer',
  double? quantity = 5,
  double cost = 100,
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return InputModel(
    id: id,
    clientUuid: clientUuid,
    sourceType: sourceType,
    sourceId: sourceId,
    animalId: animalId,
    type: type,
    quantity: quantity,
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

  group("flag OFF (today's live-HTTP behavior, except the notes wire fix)", () {
    test(
      'addInput carries fields from the Input entity into the model sent '
      'to the data source, including notes (fixes the pre-existing wire '
      "drop — the backend has always stored notes, see InputRepositoryImpl's "
      '_toModel doc comment)',
      () async {
        final dataSource = FakeInputRemoteDataSource();
        final repository = InputRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.addInput(
          Input(
            id: '',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Fertilizer',
            quantity: 5,
            cost: 100,
            date: now,
            notes: 'Top dressing',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.cost, 100);
        expect(
          dataSource.lastAdded?.notes,
          'Top dressing',
          reason:
              'the pre-existing notes drop is fixed: addInput now sends '
              'Input.notes on the wire, and the backend accepts it',
        );
      },
    );

    test(
      'updateInput carries fields from the Input entity into the model '
      'sent to the data source, including notes (fixes the pre-existing '
      'wire drop)',
      () async {
        final dataSource = FakeInputRemoteDataSource();
        final repository = InputRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.updateInput(
          Input(
            id: 'input-1',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Fertilizer',
            cost: 200,
            date: now,
            notes: 'Now reaches the wire',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.cost, 200);
        expect(
          dataSource.lastUpdated?.notes,
          'Now reaches the wire',
          reason:
              'the pre-existing notes drop is fixed: updateInput now sends '
              'Input.notes on the wire, and the backend accepts it',
        );
      },
    );

    test(
      'getInputs passes the sourceType filter straight through to the data '
      'source',
      () async {
        final dataSource = FakeInputRemoteDataSource();
        final repository = InputRepositoryImpl(remoteDataSource: dataSource);

        await repository.getInputs(sourceType: 'animal');

        expect(dataSource.lastGetSourceType, 'animal');
      },
    );

    test(
      'watchInputs does not crash and mirrors a single getInputs snapshot',
      () async {
        final dataSource = FakeInputRemoteDataSource();
        final repository = InputRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchInputs().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getInputs: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeInputRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = InputRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getInputs();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getInputs: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeInputRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = InputRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getInputs();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addInput: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeInputRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = InputRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addInput(
        Input(
          id: '',
          sourceType: 'plant',
          sourceId: 'season-1',
          type: 'Fertilizer',
          quantity: 5,
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
      'addInput: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeInputRemoteDataSource()
          ..throwOnAdd = const ServerException('cost is required');
        final repository = InputRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        final result = await repository.addInput(
          Input(
            id: '',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Fertilizer',
            quantity: 5,
            cost: 100,
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        result.fold(
          (failure) => expect(
            (failure as ServerFailure).message,
            'cost is required',
          ),
          (_) => fail('expected Left'),
        );
      },
    );

    test('a successful addInput maps to Right', () async {
      final dataSource = FakeInputRemoteDataSource();
      final repository = InputRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addInput(
        Input(
          id: '',
          sourceType: 'plant',
          sourceId: 'season-1',
          type: 'Fertilizer',
          quantity: 5,
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
    late InputLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeInputRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = InputLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeInputRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addInput upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = InputRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addInput(
          Input(
            id: '',
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Fertilizer',
            quantity: 5,
            cost: 100,
            date: now,
            notes: 'Top dressing',
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
          (input) => expect(input.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.cost, 100);
        expect(row.notes, 'Top dressing');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'input');
        expect(rows.single.clientUuid, 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateInput upserts (pending) and enqueues an update, preserving the '
      'existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _input(clientUuid: 'cu-existing', id: 'server-42', cost: 50),
          pending: false,
        );

        final repository = InputRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateInput(
          Input(
            id: 'cu-existing', // presentation id == clientUuid
            sourceType: 'plant',
            sourceId: 'season-1',
            type: 'Fertilizer',
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
      'deleteInput marks the local row deleted and enqueues a delete '
      'intent',
      () async {
        await local.upsert(_input(clientUuid: 'cu-doomed'), pending: false);

        final repository = InputRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteInput('cu-doomed');

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
      'watchInputs emits domain Inputs whose id equals the row clientUuid',
      () async {
        await local.upsert(
          _input(clientUuid: 'cu-watch-1', cost: 77),
          pending: false,
        );

        final repository = InputRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchInputs().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.cost, 77);
      },
    );

    test(
      'watchInputs(sourceType:) filters the local mirror to that source '
      'type only',
      () async {
        await local.upsert(
          _input(clientUuid: 'cu-plant', sourceType: 'plant'),
          pending: false,
        );
        await local.upsert(
          _input(clientUuid: 'cu-animal', sourceType: 'animal'),
          pending: false,
        );

        final repository = InputRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission =
            await repository.watchInputs(sourceType: 'animal').first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-animal');
      },
    );

    test(
      'getInputs (one-shot) returns local rows presented with clientUuid as '
      'id',
      () async {
        await local.upsert(_input(clientUuid: 'cu-get-1'), pending: false);

        final repository = InputRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getInputs();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          inputs,
        ) {
          expect(inputs, hasLength(1));
          expect(inputs.single.id, 'cu-get-1');
        });
      },
    );
  });
}
