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
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/cost_category_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCostCategoryRemoteDataSource implements CostCategoryRemoteDataSource {
  final List<Map<String, String?>> addCalls = [];
  final List<String> deleteCalls = [];
  List<CostCategoryModel> getCostCategoriesResult = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<CostCategoryModel>> getCostCategories({
    String? type,
    String? category,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    return getCostCategoriesResult;
  }

  @override
  Future<bool> addCostCategory({
    required String name,
    required String type,
    required String category,
    String? clientUuid,
  }) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    addCalls.add({
      'name': name,
      'type': type,
      'category': category,
      'clientUuid': clientUuid,
    });
    return true;
  }

  @override
  Future<void> deleteCostCategory(String id) async {
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

CostCategoryModel _category({
  required String clientUuid,
  String id = '',
  String name = 'Seeds',
  String type = 'plant',
  String category = 'input',
  bool isDefault = false,
}) {
  return CostCategoryModel(
    id: id,
    clientUuid: clientUuid,
    name: name,
    type: type,
    category: category,
    isDefault: isDefault,
  );
}

void main() {
  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's live-HTTP behavior, unchanged)", () {
    test(
      'addCostCategory delegates straight to the data source, never touching '
      'client_uuid',
      () async {
        final dataSource = FakeCostCategoryRemoteDataSource();
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.addCostCategory(
          name: 'Seeds',
          type: 'plant',
          category: 'input',
        );

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          success,
        ) {
          expect(success, isTrue);
        });
        expect(dataSource.addCalls, hasLength(1));
        expect(dataSource.addCalls.single['name'], 'Seeds');
        expect(
          dataSource.addCalls.single['clientUuid'],
          isNull,
          reason: 'flag-off never sends a client_uuid',
        );
      },
    );

    test('deleteCostCategory delegates straight to the data source', () async {
      final dataSource = FakeCostCategoryRemoteDataSource();
      final repository = CostCategoryRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.deleteCostCategory('cc-1');

      expect(result.isRight(), isTrue);
      expect(dataSource.deleteCalls, ['cc-1']);
    });

    test(
      'getCostCategories delegates straight to the data source with the '
      'given filters',
      () async {
        final dataSource = FakeCostCategoryRemoteDataSource()
          ..getCostCategoriesResult = [_category(clientUuid: '', id: 'cc-1')];
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.getCostCategories(
          type: 'plant',
          category: 'input',
        );

        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (categories) => expect(categories, hasLength(1)),
        );
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test(
      'getCostCategories: a NetworkException maps to NetworkFailure',
      () async {
        final dataSource = FakeCostCategoryRemoteDataSource()
          ..throwOnGet = NetworkException();
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.getCostCategories();

        result.fold(
          (failure) => expect(failure, isA<NetworkFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'getCostCategories: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeCostCategoryRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.getCostCategories();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test(
      'getCostCategories: an unexpected (non-Exceptions) error still maps to '
      'ServerFailure (this repo has an extra catch-all layer)',
      () async {
        final dataSource = FakeCostCategoryRemoteDataSource()
          ..throwOnGet = Exception('unexpected boom');
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.getCostCategories();

        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addCostCategory: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeCostCategoryRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = CostCategoryRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.addCostCategory(
        name: 'Seeds',
        type: 'plant',
        category: 'input',
      );

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'addCostCategory: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeCostCategoryRemoteDataSource()
          ..throwOnAdd = const ServerException('name is required');
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: dataSource,
        );

        final result = await repository.addCostCategory(
          name: 'Seeds',
          type: 'plant',
          category: 'input',
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

    test('a successful addCostCategory maps to Right(true)', () async {
      final dataSource = FakeCostCategoryRemoteDataSource();
      final repository = CostCategoryRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.addCostCategory(
        name: 'Seeds',
        type: 'plant',
        category: 'input',
      );

      result.fold(
        (failure) => fail('expected Right, got $failure'),
        (success) => expect(success, isTrue),
      );
    });
  });

  group('flag ON (local-first read-through)', () {
    late AppDatabase db;
    late CostCategoryLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeCostCategoryRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = CostCategoryLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeCostCategoryRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addCostCategory upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, returns Right(true), and never calls '
      'remote',
      () async {
        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );

        final result = await repository.addCostCategory(
          name: 'Seeds',
          type: 'plant',
          category: 'input',
        );

        expect(remote.addCalls, isEmpty);
        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (success) => expect(success, isTrue),
        );

        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'Seeds');
        expect(row.type, 'plant');
        expect(row.category, 'input');

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'cost_category');
        expect(rows.single.clientUuid, 'cu-new-1');

        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload, {
          'id': '',
          'name': 'Seeds',
          'type': 'plant',
          'category': 'input',
          'is_default': false,
        });

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'deleteCostCategory marks the local row deleted and enqueues a delete '
      'intent, without calling remote',
      () async {
        await local.upsert(_category(clientUuid: 'cu-doomed'), pending: false);

        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteCostCategory('cu-doomed');

        expect(remote.deleteCalls, isEmpty);
        expect(result.isRight(), isTrue);

        final row = await local.getByClientUuid('cu-doomed');
        expect(row, isNotNull);
        expect(row!.deletedLocally, isTrue);
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'delete');
        expect(rows.single.clientUuid, 'cu-doomed');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'getCostCategories (flag on) reads the local mirror, filtered by '
      'type/category, and never calls remote',
      () async {
        await local.upsert(
          _category(clientUuid: 'cu-plant-input', type: 'plant', category: 'input'),
          pending: false,
        );
        await local.upsert(
          _category(clientUuid: 'cu-animal-input', type: 'animal', category: 'input'),
          pending: false,
        );
        await local.upsert(
          _category(
            clientUuid: 'cu-plant-activity',
            type: 'plant',
            category: 'activity',
          ),
          pending: false,
        );

        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getCostCategories(
          type: 'plant',
          category: 'input',
        );

        expect(
          remote.getCostCategoriesResult,
          isEmpty,
          reason: 'never hits remote',
        );
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (categories) {
            expect(categories, hasLength(1));
            expect(categories.single.id, 'cu-plant-input');
          },
        );

        final byCategoryOnly = await repository.getCostCategories(
          category: 'activity',
        );
        byCategoryOnly.fold(
          (failure) => fail('expected Right, got $failure'),
          (categories) {
            expect(categories, hasLength(1));
            expect(categories.single.id, 'cu-plant-activity');
          },
        );
      },
    );

    test(
      'getCostCategories (flag on) excludes local tombstones',
      () async {
        await local.upsert(
          _category(clientUuid: 'cu-live', type: 'plant', category: 'input'),
          pending: false,
        );
        await local.upsert(
          _category(clientUuid: 'cu-gone', type: 'plant', category: 'input'),
          pending: false,
        );
        await local.markDeleted('cu-gone');

        final repository = CostCategoryRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getCostCategories(type: 'plant');

        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (categories) => expect(categories.map((c) => c.id), ['cu-live']),
        );
      },
    );
  });
}
