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
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/season_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSeasonRemoteDataSource implements SeasonRemoteDataSource {
  SeasonModel? lastAdded;
  SeasonModel? lastUpdated;
  final List<String> deleteCalls = [];
  Exception? throwOnGet;
  Exception? throwOnAdd;

  @override
  Future<List<SeasonModel>> getSeasons({DateTime? updatedSince}) async {
    if (throwOnGet != null) throw throwOnGet!;
    return [];
  }

  @override
  Future<SeasonModel> addSeason(SeasonModel season) async {
    if (throwOnAdd != null) throw throwOnAdd!;
    lastAdded = season;
    return season;
  }

  @override
  Future<SeasonModel> updateSeason(SeasonModel season) async {
    lastUpdated = season;
    return season;
  }

  @override
  Future<void> deleteSeason(String id) async {
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

SeasonModel _season({
  required String clientUuid,
  String id = '',
  String name = 'Long Rains 2026',
  String plantId = 'server-plant-1',
  String landId = 'server-land-1',
  DateTime? startDate,
  DateTime? endDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return SeasonModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    plantId: plantId,
    landId: landId,
    startDate: startDate ?? at,
    endDate: endDate,
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
      'addSeason carries plantId/landId from the Season entity into the '
      'model sent to the data source',
      () async {
        final dataSource = FakeSeasonRemoteDataSource();
        final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.addSeason(
          Season(
            id: '',
            userId: 'user-1',
            name: 'Long Rains 2026',
            plantId: 'plant-1',
            landId: 'land-1',
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastAdded?.plantId, 'plant-1');
        expect(dataSource.lastAdded?.landId, 'land-1');
      },
    );

    test(
      'updateSeason carries plantId/landId from the Season entity into the '
      'model sent to the data source',
      () async {
        final dataSource = FakeSeasonRemoteDataSource();
        final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        await repository.updateSeason(
          Season(
            id: 'season-1',
            userId: 'user-1',
            name: 'Long Rains 2026',
            plantId: 'plant-2',
            landId: 'land-2',
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(dataSource.lastUpdated?.plantId, 'plant-2');
        expect(dataSource.lastUpdated?.landId, 'land-2');
      },
    );

    test(
      'watchSeasons does not crash and mirrors a single getSeasons snapshot',
      () async {
        final dataSource = FakeSeasonRemoteDataSource();
        final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);

        final emission = await repository.watchSeasons().first;

        expect(emission, isEmpty);
      },
    );
  });

  group('flag OFF error mapping (R2-02 net)', () {
    test('getSeasons: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeSeasonRemoteDataSource()
        ..throwOnGet = NetworkException();
      final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getSeasons();

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test(
      'getSeasons: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeSeasonRemoteDataSource()
          ..throwOnGet = const ServerException('boom');
        final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);

        final result = await repository.getSeasons();

        result.fold(
          (failure) => expect((failure as ServerFailure).message, 'boom'),
          (_) => fail('expected Left'),
        );
      },
    );

    test('addSeason: a NetworkException maps to NetworkFailure', () async {
      final dataSource = FakeSeasonRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addSeason(
        Season(
          id: '',
          userId: 'user-1',
          name: 'Long Rains 2026',
          plantId: 'plant-1',
          landId: 'land-1',
          startDate: now,
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
      'addSeason: a ServerException(msg) maps to ServerFailure(msg)',
      () async {
        final dataSource = FakeSeasonRemoteDataSource()
          ..throwOnAdd = const ServerException('plant_id is required');
        final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);
        final now = DateTime.now();

        final result = await repository.addSeason(
          Season(
            id: '',
            userId: 'user-1',
            name: 'Long Rains 2026',
            plantId: 'plant-1',
            landId: 'land-1',
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        result.fold(
          (failure) => expect(
            (failure as ServerFailure).message,
            'plant_id is required',
          ),
          (_) => fail('expected Left'),
        );
      },
    );

    test('a successful addSeason maps to Right', () async {
      final dataSource = FakeSeasonRemoteDataSource();
      final repository = SeasonRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      final result = await repository.addSeason(
        Season(
          id: '',
          userId: 'user-1',
          name: 'Long Rains 2026',
          plantId: 'plant-1',
          landId: 'land-1',
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late SeasonLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeSeasonRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = SeasonLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeSeasonRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addSeason (create-under-an-already-synced-parent) upserts a local '
      'pending row with a minted clientUuid, enqueues a create intent, and '
      'never calls remote',
      () async {
        final repository = SeasonRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-new-1'),
        );
        final now = DateTime.now();

        final result = await repository.addSeason(
          Season(
            id: '',
            userId: 'user-1',
            name: 'Long Rains 2026',
            // Already-synced parent server ids — P3 scope (see
            // `season_model.dart`'s `// TODO(P4)` note).
            plantId: 'server-plant-1',
            landId: 'server-land-1',
            startDate: now,
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
          (season) => expect(season.id, 'cu-new-1'),
        );

        // Local row was written, pending sync.
        final row = await local.getByClientUuid('cu-new-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.name, 'Long Rains 2026');
        expect(row.plantId, 'server-plant-1');
        expect(row.landId, 'server-land-1');

        // A single create intent was enqueued.
        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'create');
        expect(rows.single.entity, 'season');
        expect(rows.single.clientUuid, 'cu-new-1');

        // The staged payload preserves the date-only serialization.
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['start_date'], now.toIso8601String().split('T')[0]);
        expect(payload['client_uuid'], 'cu-new-1');

        // Sync was fired (fire-and-forget).
        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'updateSeason upserts (pending) and enqueues an update, preserving '
      'the existing serverId',
      () async {
        // Seed a row that already synced once (has a serverId), not pending.
        await local.upsert(
          _season(clientUuid: 'cu-existing', id: 'server-42', name: 'Old'),
          pending: false,
        );

        final repository = SeasonRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.updateSeason(
          Season(
            id: 'cu-existing', // presentation id == clientUuid
            userId: 'user-1',
            name: 'New Name',
            plantId: 'server-plant-1',
            landId: 'server-land-1',
            startDate: DateTime.utc(2026),
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
        expect(row.pending, isTrue);

        final rows = await outbox.peekAll();
        expect(rows, hasLength(1));
        expect(rows.single.op, 'update');
        expect(rows.single.clientUuid, 'cu-existing');
        final payload =
            jsonDecode(rows.single.payload!) as Map<String, dynamic>;
        expect(payload['id'], 'server-42');

        expect(sync.syncNowCalls, 1);
      },
    );

    test(
      'deleteSeason marks the local row deleted and enqueues a delete '
      'intent',
      () async {
        await local.upsert(_season(clientUuid: 'cu-doomed'), pending: false);

        final repository = SeasonRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.deleteSeason('cu-doomed');

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
      'watchSeasons emits domain Seasons whose id equals the row clientUuid',
      () async {
        await local.upsert(
          _season(clientUuid: 'cu-watch-1', name: 'Watched Season'),
          pending: false,
        );

        final repository = SeasonRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final emission = await repository.watchSeasons().first;

        expect(emission, hasLength(1));
        expect(emission.single.id, 'cu-watch-1');
        expect(emission.single.name, 'Watched Season');
      },
    );

    test(
      'getSeasons (one-shot) returns local rows presented with clientUuid '
      'as id',
      () async {
        await local.upsert(_season(clientUuid: 'cu-get-1'), pending: false);

        final repository = SeasonRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
        );

        final result = await repository.getSeasons();

        expect(result.isRight(), isTrue);
        result.fold((failure) => fail('expected Right, got $failure'), (
          seasons,
        ) {
          expect(seasons, hasLength(1));
          expect(seasons.single.id, 'cu-get-1');
        });
      },
    );
  });
}
