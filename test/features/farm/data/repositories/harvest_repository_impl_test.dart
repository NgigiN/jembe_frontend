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
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/harvest_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHarvestRemoteDataSource implements HarvestRemoteDataSource {
  HarvestModel? lastAdded;
  HarvestModel? lastUpdated;
  String? lastGetSeasonId;
  final List<String> deleteCalls = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<HarvestModel>> getHarvests({
    String? seasonId,
    DateTime? updatedSince,
  }) async {
    if (throwOnGet != null) throw throwOnGet!;
    lastGetSeasonId = seasonId;
    return [];
  }

  @override
  Future<HarvestModel> addHarvest(HarvestModel harvest) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = harvest;
    return harvest;
  }

  @override
  Future<HarvestModel> updateHarvest(HarvestModel harvest) async {
    lastUpdated = harvest;
    return harvest;
  }

  @override
  Future<void> deleteHarvest(String id) async {
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

HarvestModel _harvest({
  required String clientUuid,
  String id = '',
  String seasonId = 'season-1',
  double quantity = 10,
  String unit = 'kg',
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return HarvestModel(
    id: id,
    clientUuid: clientUuid,
    seasonId: seasonId,
    quantity: quantity,
    unit: unit,
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
      'addHarvest carries fields from the Harvest entity into the model '
      'sent to the data source',
      () async {
        final dataSource = FakeHarvestRemoteDataSource();
        final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.addHarvest(
          Harvest(
            id: '',
            seasonId: 'season-1',
            quantity: 12.5,
            unit: 'kg',
            date: now,
            notes: 'Good yield',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.quantity, 12.5);
        expect(dataSource.lastAdded?.notes, 'Good yield');
      },
    );

    test(
      'updateHarvest carries fields from the Harvest entity into the model '
      'sent to the data source',
      () async {
        final dataSource = FakeHarvestRemoteDataSource();
        final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.updateHarvest(
          Harvest(
            id: 'harvest-1',
            seasonId: 'season-1',
            quantity: 20,
            unit: 'sacks',
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.quantity, 20);
        expect(dataSource.lastUpdated?.unit, 'sacks');
      },
    );

    test(
      'getHarvests passes the seasonId filter straight through to the data '
      'source',
      () async {
        final dataSource = FakeHarvestRemoteDataSource();
        final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);

        await repository.getHarvests(seasonId: 'season-9');

        expect(dataSource.lastGetSeasonId, 'season-9');
      },
    );

    test(
      'watchHarvests does not crash and mirrors a single getHarvests '
      'snapshot',
      () async {
        final dataSource = FakeHarvestRemoteDataSource();
        final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchHarvests().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getHarvests: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeHarvestRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getHarvests();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getHarvests: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeHarvestRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getHarvests();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addHarvest: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeHarvestRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addHarvest(
        Harvest(
          id: '',
          seasonId: 'season-1',
          quantity: 10,
          unit: 'kg',
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
      'addHarvest: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeHarvestRemoteDataSource()
          ..throwOnAdd = const ServerException('quantity is required');
        final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        final result = await repository.addHarvest(
          Harvest(
            id: '',
            seasonId: 'season-1',
            quantity: 10,
            unit: 'kg',
            date: now,
            createdAt: now,
            updatedAt: now,
          ),
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

    test('a successful addHarvest maps to Right', () async {
      final dataSource = FakeHarvestRemoteDataSource();
      final repository = HarvestRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addHarvest(
        Harvest(
          id: '',
          seasonId: 'season-1',
          quantity: 10,
          unit: 'kg',
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
    late HarvestLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeHarvestRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = HarvestLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeHarvestRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addHarvest upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, and never calls remote',
      () async {
        final repository = HarvestRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addHarvest(
          Harvest(
            id: '',
            seasonId: 'season-1',
            quantity: 12.5,
            unit: 'kg',
            date: now,
            notes: 'Good yield',
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
          (harvest) => expect(harvest.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.quantity, 12.5);
        expect(row.notes, 'Good yield');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'harvest');
        expect(rows.single.clientUuid, 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateHarvest upserts (pending) and enqueues an update, preserving '
      'the existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _harvest(clientUuid: 'cu-existing', id: 'server-42', quantity: 5),
          pending: false,
        );

        final repository = HarvestRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateHarvest(
          Harvest(
            id: 'cu-existing', // presentation id == clientUuid
            seasonId: 'season-1',
            quantity: 99,
            unit: 'kg',
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
        expect(row.quantity, 99);
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['quantity'], 99);

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'deleteHarvest marks the local row deleted and enqueues a delete '
      'intent',
      () async {
        await local.upsert(_harvest(clientUuid: 'cu-doomed'), pending: false);

        final repository = HarvestRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteHarvest('cu-doomed');

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
      'watchHarvests emits domain Harvests whose id equals the row '
      'clientUuid',
      () async {
        await local.upsert(
          _harvest(clientUuid: 'cu-watch-1', quantity: 7),
          pending: false,
        );

        final repository = HarvestRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchHarvests().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.quantity, 7);
      },
    );

    test(
      'watchHarvests(seasonId:) filters the local mirror to that season only',
      () async {
        await local.upsert(
          _harvest(clientUuid: 'cu-season-a', seasonId: 'season-a'),
          pending: false,
        );
        await local.upsert(
          _harvest(clientUuid: 'cu-season-b', seasonId: 'season-b'),
          pending: false,
        );

        final repository = HarvestRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission =
            await repository.watchHarvests(seasonId: 'season-a').first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-season-a');
      },
    );

    test(
      'getHarvests (one-shot) returns local rows presented with clientUuid '
      'as id',
      () async {
        await local.upsert(_harvest(clientUuid: 'cu-get-1'), pending: false);

        final repository = HarvestRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getHarvests();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          harvests,
        ) {
          expect(harvests, hasLength(1));
          expect(harvests.single.id, 'cu-get-1');
        });
      },
    );
  });
}
