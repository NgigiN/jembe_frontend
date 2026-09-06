import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';
import 'package:farm_tracker/features/farm/data/sync/cost_category_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controllable fake of [CostCategoryRemoteDataSource] — records every call
/// so tests can assert exactly what [CostCategorySyncer] sent, and lets a
/// test inject a canned response or a thrown exception per method.
class _FakeCostCategoryRemoteDataSource implements CostCategoryRemoteDataSource {
  final List<Map<String, String?>> addCalls = [];
  final List<String> deleteCalls = [];
  final List<Map<String, String?>> getCostCategoriesCalls = [];
  List<CostCategoryModel> getCostCategoriesResult = [];
  bool addResult = true;
  Exception? throwOnAdd;
  Exception? throwOnGet;

  @override
  Future<List<CostCategoryModel>> getCostCategories({
    String? type,
    String? category,
  }) async {
    getCostCategoriesCalls.add({'type': type, 'category': category});
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
    addCalls.add({
      'name': name,
      'type': type,
      'category': category,
      'clientUuid': clientUuid,
    });
    if (throwOnAdd != null) throw throwOnAdd!;
    return addResult;
  }

  @override
  Future<void> deleteCostCategory(String id) async {
    deleteCalls.add(id);
  }
}

CostCategoryModel _category({
  required String clientUuid,
  String id = '',
  String name = 'Seeds',
  String type = 'plant',
  String category = 'input',
  bool isDefault = false,
  bool pending = false,
  bool deletedLocally = false,
}) {
  return CostCategoryModel(
    id: id,
    clientUuid: clientUuid,
    name: name,
    type: type,
    category: category,
    isDefault: isDefault,
    pending: pending,
    deletedLocally: deletedLocally,
  );
}

OutboxRow _entry({required String op, required String clientUuid, int seq = 1}) {
  return OutboxRow(
    seq: seq,
    entity: 'cost_category',
    op: op,
    clientUuid: clientUuid,
    attempts: 0,
    state: 'pending',
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  late AppDatabase db;
  late CostCategoryLocalDataSource local;
  late _FakeCostCategoryRemoteDataSource remote;
  late CostCategorySyncer syncer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = CostCategoryLocalDataSource(db);
    remote = _FakeCostCategoryRemoteDataSource();
    syncer = CostCategorySyncer(remote: remote, local: local);
  });

  tearDown(() async {
    await db.close();
  });

  test('entity is "cost_category"', () {
    expect(syncer.entity, 'cost_category');
  });

  group('push — create', () {
    test(
      'calls addCostCategory with client_uuid and marks the local row '
      'synced WITHOUT assigning a server id',
      () async {
        await local.upsert(
          _category(
            clientUuid: 'cu-1',
            name: 'Seeds',
            type: 'plant',
            category: 'input',
          ),
          pending: true,
        );

        await syncer.push(_entry(op: 'create', clientUuid: 'cu-1'));

        expect(remote.addCalls, hasLength(1));
        expect(remote.addCalls.single['name'], 'Seeds');
        expect(remote.addCalls.single['type'], 'plant');
        expect(remote.addCalls.single['category'], 'input');
        expect(remote.addCalls.single['clientUuid'], 'cu-1');

        final row = await local.getByClientUuid('cu-1');
        expect(row, isNotNull);
        expect(row!.pending, isFalse);
        expect(
          row.id,
          '',
          reason:
              'the create response is a bare bool — no server id to learn '
              'here; the next pull re-fetch assigns it',
        );
      },
    );

    test('is a no-op when the local row is gone (annihilated)', () async {
      await syncer.push(_entry(op: 'create', clientUuid: 'missing'));

      expect(remote.addCalls, isEmpty);
    });

    test(
      'a false return from addCostCategory leaves the row pending (not '
      'reached by the real data source, but handled defensively)',
      () async {
        await local.upsert(_category(clientUuid: 'cu-1'), pending: true);
        remote.addResult = false;

        await syncer.push(_entry(op: 'create', clientUuid: 'cu-1'));

        final row = await local.getByClientUuid('cu-1');
        expect(row!.pending, isTrue);
      },
    );

    test(
      'a NetworkException from addCostCategory propagates (not swallowed)',
      () async {
        await local.upsert(_category(clientUuid: 'cu-1'), pending: true);
        remote.throwOnAdd = NetworkException();

        await expectLater(
          syncer.push(_entry(op: 'create', clientUuid: 'cu-1')),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'a ServerException from addCostCategory propagates (not swallowed)',
      () async {
        await local.upsert(_category(clientUuid: 'cu-1'), pending: true);
        remote.throwOnAdd = const ServerException('bad request');

        await expectLater(
          syncer.push(_entry(op: 'create', clientUuid: 'cu-1')),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });

  group('push — update', () {
    test('is a no-op — cost_category has no update', () async {
      await local.upsert(
        _category(clientUuid: 'cu-1', id: 'server-1'),
        pending: true,
      );

      await syncer.push(_entry(op: 'update', clientUuid: 'cu-1'));

      expect(remote.addCalls, isEmpty);
      expect(remote.deleteCalls, isEmpty);
    });
  });

  group('push — delete', () {
    test(
      'calls deleteCostCategory with the server id then hard-deletes '
      'locally',
      () async {
        await local.upsert(
          _category(clientUuid: 'cu-1', id: 'server-1'),
          pending: false,
        );
        await local.markDeleted('cu-1');

        await syncer.push(_entry(op: 'delete', clientUuid: 'cu-1'));

        expect(remote.deleteCalls, ['server-1']);
        expect(await local.getByClientUuid('cu-1'), isNull);
      },
    );

    test(
      'a row that never synced (no server id) is just hard-deleted locally',
      () async {
        await local.upsert(_category(clientUuid: 'cu-1'), pending: true);
        await local.markDeleted('cu-1');

        await syncer.push(_entry(op: 'delete', clientUuid: 'cu-1'));

        expect(remote.deleteCalls, isEmpty);
        expect(await local.getByClientUuid('cu-1'), isNull);
      },
    );

    test('is a no-op when the local row is already gone', () async {
      await syncer.push(_entry(op: 'delete', clientUuid: 'missing'));

      expect(remote.deleteCalls, isEmpty);
    });
  });

  group('pull', () {
    test(
      'FULL re-fetch: replaces every non-pending local row with the server '
      'rows, keyed "srv:" + serverId, and returns null (no cursor)',
      () async {
        await local.upsert(
          _category(
            clientUuid: 'cu-stale',
            name: 'Stale',
            type: 'plant',
            category: 'input',
          ),
          pending: false,
        );
        remote.getCostCategoriesResult = [
          _category(
            clientUuid: '',
            id: 'server-1',
            name: 'Seeds',
            type: 'plant',
            category: 'input',
          ),
          _category(
            clientUuid: '',
            id: 'server-2',
            name: 'Labor',
            type: 'plant',
            category: 'activity',
          ),
        ];

        final cursor = await syncer.pull(null);

        expect(cursor, isNull);
        expect(remote.getCostCategoriesCalls.single, {
          'type': null,
          'category': null,
        }, reason: 'the pull must be UNFILTERED — no updatedSince either');

        final rows = await db.select(db.costCategories).get();
        expect(
          rows.map((r) => r.clientUuid).toSet(),
          {'srv:server-1', 'srv:server-2'},
        );
        expect(
          await local.getByClientUuid('cu-stale'),
          isNull,
          reason: 'the stale non-pending row is replaced by the re-fetch',
        );

        final seeds = await local.getByServerId('server-1');
        expect(seeds, isNotNull);
        expect(seeds!.name, 'Seeds');
        expect(seeds.pending, isFalse);
      },
    );

    test(
      'PRESERVES a pending local row (an offline create/delete awaiting '
      'push) untouched by the full re-fetch',
      () async {
        await local.upsert(
          _category(
            clientUuid: 'cu-pending-create',
            name: 'New one',
            type: 'plant',
            category: 'input',
          ),
          pending: true,
        );
        remote.getCostCategoriesResult = [
          _category(
            clientUuid: '',
            id: 'server-1',
            name: 'Seeds',
            type: 'plant',
            category: 'input',
          ),
        ];

        await syncer.pull(null);

        final pendingRow = await local.getByClientUuid('cu-pending-create');
        expect(pendingRow, isNotNull);
        expect(pendingRow!.pending, isTrue);
        expect(pendingRow.name, 'New one');

        final seeds = await local.getByServerId('server-1');
        expect(seeds, isNotNull);
      },
    );

    test(
      'is idempotent: re-running pull with the same server rows converges '
      'to the same final state',
      () async {
        remote.getCostCategoriesResult = [
          _category(
            clientUuid: '',
            id: 'server-1',
            name: 'Seeds',
            type: 'plant',
            category: 'input',
          ),
        ];

        await syncer.pull(null);
        final firstRows = await db.select(db.costCategories).get();

        await syncer.pull(null);
        final secondRows = await db.select(db.costCategories).get();

        expect(secondRows, hasLength(1));
        expect(secondRows.single.clientUuid, firstRows.single.clientUuid);
        expect(secondRows.single.name, 'Seeds');
        expect(secondRows.single.pending, isFalse);
      },
    );

    test(
      'a NetworkException from getCostCategories propagates (not swallowed)',
      () async {
        remote.throwOnGet = NetworkException();

        await expectLater(syncer.pull(null), throwsA(isA<NetworkException>()));
      },
    );

    test(
      'a ServerException from getCostCategories propagates (not swallowed)',
      () async {
        remote.throwOnGet = const ServerException('boom');

        await expectLater(syncer.pull(null), throwsA(isA<ServerException>()));
      },
    );
  });
}
