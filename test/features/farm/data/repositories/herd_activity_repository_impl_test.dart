import 'dart:convert';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/herd_activity_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHerdActivityRemoteDataSource implements HerdActivityRemoteDataSource {
  HerdActivityModel? lastAdded;
  String? lastHerdId;
  Exception? throwOnAdd;

  @override
  Future<HerdActivityModel> addHerdActivity(
    String herdId,
    HerdActivityModel activity,
  ) async {
    lastHerdId = herdId;
    lastAdded = activity;
    if (throwOnAdd != null) throw throwOnAdd!;
    return activity;
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

void main() {
  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's live-HTTP behavior, unchanged)", () {
    test(
      'addHerdActivity delegates straight to the data source and returns '
      'its result',
      () async {
        final dataSource = FakeHerdActivityRemoteDataSource();
        final repository = HerdActivityRepositoryImpl(
          remoteDataSource: dataSource,
        );
        final date = DateTime.utc(2026, 9);

        final result = await repository.addHerdActivity(
          'herd-1',
          'birth',
          3,
          date,
          'twins + one more',
        );

        expect(result.isRight(), isTrue);
        expect(dataSource.lastHerdId, 'herd-1');
        expect(dataSource.lastAdded, isNotNull);
        expect(dataSource.lastAdded!.herdId, 'herd-1');
        expect(dataSource.lastAdded!.activityType, 'birth');
        expect(dataSource.lastAdded!.count, 3);
        expect(dataSource.lastAdded!.notes, 'twins + one more');
      },
    );

    test('a NetworkException from the data source maps to NetworkFailure', () async {
      final dataSource = FakeHerdActivityRemoteDataSource()
        ..throwOnAdd = NetworkException();
      final repository = HerdActivityRepositoryImpl(
        remoteDataSource: dataSource,
      );

      final result = await repository.addHerdActivity(
        'herd-1',
        'birth',
        1,
        DateTime.utc(2026, 9),
        null,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('flag ON (local-first + outbox)', () {
    late AppDatabase db;
    late HerdActivityLocalDataSource local;
    late OutboxDao outbox;
    late _FakeSyncEngine sync;
    late FakeHerdActivityRemoteDataSource remote;

    setUp(() {
      OfflineConfig.enabled = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      local = HerdActivityLocalDataSource(db);
      outbox = OutboxDao(db);
      sync = _FakeSyncEngine();
      remote = FakeHerdActivityRemoteDataSource();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'addHerdActivity upserts a local pending row with a minted clientUuid, '
      'enqueues a create intent, kicks syncNow, returns Right(model), and '
      'never calls remote',
      () async {
        final repository = HerdActivityRepositoryImpl(
          remoteDataSource: remote,
          local: local,
          outbox: outbox,
          sync: sync,
          uuid: const _FixedUuidGen('cu-activity-1'),
        );
        final date = DateTime.utc(2026, 9);

        final result = await repository.addHerdActivity(
          'herd-1',
          'fatality',
          2,
          date,
          'lion attack',
        );

        expect(remote.lastAdded, isNull, reason: 'never calls remote');
        expect(result.isRight(), isTrue);
        result.fold(
          (failure) => fail('expected Right, got $failure'),
          (activity) {
            expect(activity.herdId, 'herd-1');
            expect(activity.activityType, 'fatality');
            expect(activity.count, 2);
            expect(activity.notes, 'lion attack');
          },
        );

        final row = await local.getByClientUuid('cu-activity-1');
        expect(row, isNotNull);
        expect(row!.pending, isTrue);
        expect(row.herdId, 'herd-1');
        expect(row.activityType, 'fatality');
        expect(row.count, 2);
        expect(row.notes, 'lion attack');

        final outboxRows = await outbox.peekAll();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.op, 'create');
        expect(outboxRows.single.entity, 'herd_activity');
        expect(outboxRows.single.clientUuid, 'cu-activity-1');

        final payload =
            jsonDecode(outboxRows.single.payload!) as Map<String, dynamic>;
        expect(payload, {
          'activity_type': 'fatality',
          'count': 2,
          'date': date.toUtc().toIso8601String(),
          'reason': 'lion attack',
        }, reason: 'toJson omits herdId and uses reason for notes');

        expect(sync.syncNowCalls, 1);
      },
    );
  });
}
