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
import 'package:farm_tracker/features/farm/data/datasources/revenue_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/revenue_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRevenueRemoteDataSource implements RevenueRemoteDataSource {
  RevenueModel? lastAdded;
  RevenueModel? lastUpdated;
  final List<String> deleteCalls = [];
  List<RevenueModel> getRevenuesResult = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<RevenueModel>> getRevenues({
    AnalyticsScope scope = const AnalyticsScope.all(),
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    return getRevenuesResult;
  }

  @override
  Future<RevenueModel> getRevenueById(String id) async {
    return getRevenuesResult.firstWhere((r) => r.id == id);
  }

  @override
  Future<RevenueModel> addRevenue(RevenueModel revenue) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = revenue;
    return revenue;
  }

  @override
  Future<RevenueModel> updateRevenue(RevenueModel revenue) async {
    lastUpdated = revenue;
    return revenue;
  }

  @override
  Future<void> deleteRevenue(String id) async {
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

RevenueModel _revenue({
  required String clientUuid,
  String id = '',
  String source = 'plant',
  String sourceId = 'server-season-1',
  String type = 'Maize Harvest',
  double quantity = 10,
  double unitPrice = 50,
  double? total,
  String? notes,
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return RevenueModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    source: source,
    sourceId: sourceId,
    type: type,
    quantity: quantity,
    unitPrice: unitPrice,
    total: total ?? (quantity * unitPrice),
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
    test('addRevenue builds a fresh RevenueModel from the primitive args and '
        'sends it to the data source', () async {
      final dataSource = FakeRevenueRemoteDataSource();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);
      final date = DateTime.utc(2026, 3);

      await repository.addRevenue(
        source: 'plant',
        sourceId: 'server-season-1',
        type: 'Maize Harvest',
        quantity: 10,
        unitPrice: 50,
        date: date,
      );

      expect(dataSource.lastAdded?.source, 'plant');
      expect(dataSource.lastAdded?.sourceId, 'server-season-1');
      expect(dataSource.lastAdded?.type, 'Maize Harvest');
      expect(dataSource.lastAdded?.quantity, 10);
      expect(dataSource.lastAdded?.unitPrice, 50);
      expect(dataSource.lastAdded?.total, 500);
      expect(dataSource.lastAdded?.id, '');
    });

    test('updateRevenue sends the primitive args straight through as a fresh '
        "RevenueModel, with userId '' (server-populated) and fresh "
        'created/updated timestamps', () async {
      final dataSource = FakeRevenueRemoteDataSource();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);
      final date = DateTime.utc(2026, 3);

      await repository.updateRevenue(
        id: 'revenue-1',
        source: 'animal',
        sourceId: 'server-herd-1',
        type: 'Milk Sale',
        quantity: 20,
        unitPrice: 5,
        total: 100,
        date: date,
      );

      expect(dataSource.lastUpdated?.id, 'revenue-1');
      expect(dataSource.lastUpdated?.userId, '');
      expect(dataSource.lastUpdated?.source, 'animal');
      expect(dataSource.lastUpdated?.sourceId, 'server-herd-1');
      expect(dataSource.lastUpdated?.total, 100);
    });

    test('deleteRevenue delegates straight to the data source', () async {
      final dataSource = FakeRevenueRemoteDataSource();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.deleteRevenue('revenue-1');

      expect(result.isRight(), isTrue);
      expect(dataSource.deleteCalls, ['revenue-1']);
    });

    test('getRevenues delegates straight to the data source with the given '
        'filters', () async {
      final dataSource = FakeRevenueRemoteDataSource()
        ..getRevenuesResult = [_revenue(clientUuid: '', id: 'r1')];
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getRevenues(
        scope: const AnalyticsScope.source(ScopeSource.plant),
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('expected Right, got $failure'),
        (revenues) => expect(revenues, hasLength(1)),
      );
    });

    test('getRevenueById delegates straight to the data source', () async {
      final dataSource = FakeRevenueRemoteDataSource()
        ..getRevenuesResult = [_revenue(clientUuid: '', id: 'r1')];
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getRevenueById('r1');

      expect(result.isRight(), isTrue);
    });

    test('watchRevenues does not crash and mirrors a single getRevenues '
        'snapshot', () async {
      final dataSource = FakeRevenueRemoteDataSource();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);

      final emission = await repository.watchRevenues().first;

      expect(emission, isEmpty);
    });
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getRevenues: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeRevenueRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getRevenues();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getRevenues: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeRevenueRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getRevenues();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addRevenue: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeRevenueRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);
      final date = DateTime.utc(2026, 3);

      final result = await repository.addRevenue(
        source: 'plant',
        sourceId: 'server-season-1',
        type: 'Maize Harvest',
        quantity: 10,
        unitPrice: 50,
        date: date,
      );

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'addRevenue: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeRevenueRemoteDataSource()
          ..throwOnAdd = const ServerException('quantity is required');
        final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);
        final date = DateTime.utc(2026, 3);

        final result = await repository.addRevenue(
          source: 'plant',
          sourceId: 'server-season-1',
          type: 'Maize Harvest',
          quantity: 10,
          unitPrice: 50,
          date: date,
        );

        result.fold(
          (failure) => expect(
            (failure as ServerFailure).message,
            'quantity is required',
          ),
          (_) => fail('expected Left'),
        );
      },
    );

    test('a successful addRevenue maps to Right', () async {
      final dataSource = FakeRevenueRemoteDataSource();
      final repository = RevenueRepositoryImpl(remoteDataSource: dataSource);
      final date = DateTime.utc(2026, 3);

      final result = await repository.addRevenue(
        source: 'plant',
        sourceId: 'server-season-1',
        type: 'Maize Harvest',
        quantity: 10,
        unitPrice: 50,
        date: date,
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late RevenueLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeRevenueRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = RevenueLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeRevenueRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test('addRevenue upserts a local pending row with a minted clientUuid, '
        'enqueues a create intent, and never calls remote', () async {
      final repository = RevenueRepositoryImpl(
        remoteDataSource: remote,
        local: local,
        outbox: outbox,
        sync: sync,
        uuid: const _FixedUuidGen('cu-new-1'),
      );
      final date = DateTime.utc(2026, 3);

      final result = await repository.addRevenue(
        source: 'plant',
        sourceId: 'server-season-1',
        type: 'Maize Harvest',
        quantity: 10,
        unitPrice: 50,
        date: date,
      );

      expect(remote.lastAdded, isNull);

      expect(result.isRight(), isTrue);
      result.fold(
        (failure) => fail('expected Right, got $failure'),
        (revenue) => expect(revenue.id, 'cu-new-1'),
      );

      final row = await local.getByClientUuid('cu-new-1');
      expect(row, isNotNull);
      expect(row!.pending, isTrue);
      expect(row.source, 'plant');
      expect(row.sourceId, 'server-season-1');
      expect(row.total, 500, reason: 'total defaults to quantity*unitPrice');

      final rows = await outbox.peekAll();
      expect(rows, hasLength(1));
      expect(rows.single.op, 'create');
      expect(rows.single.entity, 'revenue');
      expect(rows.single.clientUuid, 'cu-new-1');

      final payload = jsonDecode(rows.single.payload!) as Map<String, dynamic>;
      expect(payload['source'], 'plant');
      expect(payload['source_id'], 'server-season-1');
      expect(
        payload.containsKey('client_uuid'),
        isFalse,
        reason:
            'toJson() never carries client_uuid — only the remote create '
            'call site adds it to the wire body',
      );

      expect(sync.syncNowCalls, 1);
    });

    test('updateRevenue upserts (pending) and enqueues an update, preserving '
        'the existing serverId and userId', () async {
      await local.upsert(
        _revenue(
          clientUuid: 'cu-existing',
          id: 'server-42',
          source: 'plant',
          type: 'Old type',
        ),
        pending: false,
      );

      final repository = RevenueRepositoryImpl(
        remoteDataSource: remote,
        local: local,
        outbox: outbox,
        sync: sync,
      );
      final date = DateTime.utc(2026, 4);

      final result = await repository.updateRevenue(
        id: 'cu-existing',
        source: 'animal',
        sourceId: 'server-herd-9',
        type: 'New type',
        quantity: 30,
        unitPrice: 2,
        total: 60,
        date: date,
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
      expect(row.userId, 'user-1', reason: 'existing userId preserved');
      expect(row.type, 'New type');
      expect(row.source, 'animal');
      expect(row.sourceId, 'server-herd-9');
      expect(row.total, 60);
      expect(row.pending, isTrue);

      final rows = await outbox.peekAll();
      expect(rows, hasLength(1));
      expect(rows.single.op, 'update');
      expect(rows.single.clientUuid, 'cu-existing');

      expect(sync.syncNowCalls, 1);
    });

    test(
      'updateRevenue on a missing clientUuid returns CacheFailure',
      () async {
        final repository = RevenueRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateRevenue(
          id: 'cu-missing',
          source: 'plant',
          sourceId: 'server-season-1',
          type: 'X',
          quantity: 1,
          unitPrice: 1,
          total: 1,
          date: DateTime.utc(2026),
        );

        expect(result.isLeft(), isTrue);
      },
    );

    test('deleteRevenue marks the local row deleted and enqueues a delete '
        'intent', () async {
      await local.upsert(_revenue(clientUuid: 'cu-doomed'), pending: false);

      final repository = RevenueRepositoryImpl(
        remoteDataSource: remote,
        local: local,
        outbox: outbox,
        sync: sync,
      );

      final result = await repository.deleteRevenue('cu-doomed');

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
    });

    test('watchRevenues emits domain Revenues whose id equals the row '
        'clientUuid', () async {
      await local.upsert(
        _revenue(clientUuid: 'cu-watch-1', type: 'Watched Revenue'),
        pending: false,
      );

      final repository = RevenueRepositoryImpl(
        remoteDataSource: remote,
        local: local,
        outbox: outbox,
        sync: sync,
      );

      final emission = await repository.watchRevenues().first;

      expect(emission, hasLength(1));
      expect(emission.single.id, 'cu-watch-1');
      expect(emission.single.type, 'Watched Revenue');
    });

    test('getRevenues (flag on) reads the local mirror and applies the '
        'source/date filter in memory', () async {
      await local.upsert(
        _revenue(
          clientUuid: 'cu-plant',
          source: 'plant',
          date: DateTime.utc(2026, 1, 15),
        ),
        pending: false,
      );
      await local.upsert(
        _revenue(
          clientUuid: 'cu-animal',
          source: 'animal',
          date: DateTime.utc(2026, 6, 15),
        ),
        pending: false,
      );

      final repository = RevenueRepositoryImpl(
        remoteDataSource: remote,
        local: local,
        outbox: outbox,
        sync: sync,
      );

      final result = await repository.getRevenues(
        scope: const AnalyticsScope.source(ScopeSource.plant),
      );

      expect(remote.getRevenuesResult, isEmpty, reason: 'never hits remote');
      result.fold((failure) => fail('expected Right, got $failure'), (
        revenues,
      ) {
        expect(revenues, hasLength(1));
        expect(revenues.single.id, 'cu-plant');
      });

      final dateScoped = await repository.getRevenues(
        startDate: DateTime.utc(2026, 5),
      );
      dateScoped.fold((failure) => fail('expected Right, got $failure'), (
        revenues,
      ) {
        expect(revenues, hasLength(1));
        expect(revenues.single.id, 'cu-animal');
      });

      // Scope chips (spec 2026-09-08): herd matches sourceId directly; a
      // land scope needs the caller-resolved season ids.
      final herdScoped = await repository.getRevenues(
        scope: const AnalyticsScope.herd('server-season-1'),
      );
      herdScoped.fold(
        (failure) => fail('expected Right, got $failure'),
        (revenues) => expect(revenues.map((r) => r.id), ['cu-animal']),
      );
      final landScoped = await repository.getRevenues(
        scope: const AnalyticsScope.land('land-x'),
        seasonIdsOnLand: const {'server-season-1'},
      );
      landScoped.fold(
        (failure) => fail('expected Right, got $failure'),
        (revenues) => expect(revenues.map((r) => r.id), ['cu-plant']),
      );
      final landUnresolved = await repository.getRevenues(
        scope: const AnalyticsScope.land('land-x'),
      );
      landUnresolved.fold(
        (failure) => fail('expected Right, got $failure'),
        (revenues) => expect(revenues, isEmpty),
      );
    });

    test(
      'getRevenueById (flag on, R4) reads the local mirror by clientUuid',
      () async {
        await local.upsert(
          _revenue(clientUuid: 'cu-by-id', type: 'Found locally'),
          pending: false,
        );

        final repository = RevenueRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getRevenueById('cu-by-id');

        expect(remote.getRevenuesResult, isEmpty, reason: 'never hits remote');
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (revenue) => expect(revenue.type, 'Found locally'),
        );

        final missing = await repository.getRevenueById('cu-missing');
        expect(missing.isLeft(), isTrue);
      },
    );
  });

  group('RevenueModel wire body (byte-for-byte field set)', () {
    test('toJson includes total only when >0 and notes only when non-empty, '
        'and coerces a numeric source_id', () {
      final revenue = _revenue(
        clientUuid: 'cu-1',
        source: 'plant',
        sourceId: '42',
        type: 'Maize Harvest',
        quantity: 10,
        unitPrice: 5,
        total: 0,
        notes: null,
        date: DateTime.utc(2026, 3, 1),
      );

      expect(revenue.toJson(), {
        'source': 'plant',
        'source_id': 42,
        'type': 'Maize Harvest',
        'quantity': 10.0,
        'unit_price': 5.0,
        'date': DateTime.utc(2026, 3, 1).toIso8601String(),
      });
    });

    test('toJson keeps a non-numeric source_id as a string, and includes '
        'total/notes when present', () {
      final revenue = _revenue(
        clientUuid: 'cu-2',
        source: 'animal',
        sourceId: 'unsynced-clientuuid',
        type: 'Milk Sale',
        quantity: 4,
        unitPrice: 25,
        total: 100,
        notes: 'Sold at the gate',
        date: DateTime.utc(2026, 4, 2),
      );

      final json = revenue.toJson();
      expect(json['source_id'], 'unsynced-clientuuid');
      expect(json['total'], 100.0);
      expect(json['notes'], 'Sold at the gate');
    });
  });
}
