import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/data/sync/herd_activity_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controllable fake of [HerdActivityRemoteDataSource] — records every call
/// so tests can assert exactly what [HerdActivitySyncer] sent, and lets a
/// test inject a canned response or a thrown exception.
class _FakeHerdActivityRemoteDataSource
    implements HerdActivityRemoteDataSource {
  final List<String> herdIdCalls = [];
  final List<HerdActivityModel> addedModels = [];
  HerdActivityModel Function(String herdId, HerdActivityModel model)?
  responseBuilder;
  Exception? throwOnAdd;

  @override
  Future<HerdActivityModel> addHerdActivity(
    String herdId,
    HerdActivityModel activity,
  ) async {
    herdIdCalls.add(herdId);
    addedModels.add(activity);
    if (throwOnAdd != null) throw throwOnAdd!;
    if (responseBuilder != null) return responseBuilder!(herdId, activity);
    return HerdActivityModel(
      id: 'server-1',
      herdId: herdId,
      activityType: activity.activityType,
      count: activity.count,
      date: activity.date,
      notes: activity.notes,
      createdAt: DateTime.utc(2026, 9, 6, 12),
    );
  }
}

HerdActivityModel _activity({
  required String clientUuid,
  String id = '',
  // Numeric == already-synced-herd semantics: `resolveFkOrThrow` returns a
  // numeric value unchanged (no resolver lookup needed), so tests that don't
  // care about FK translation can use `FkResolver(const {})` untouched.
  String herdId = '1',
  String activityType = 'birth',
  int count = 1,
  DateTime? date,
  String? notes,
  bool pending = false,
  bool deletedLocally = false,
}) {
  return HerdActivityModel(
    id: id,
    clientUuid: clientUuid,
    herdId: herdId,
    activityType: activityType,
    count: count,
    date: date ?? DateTime.utc(2026, 9),
    notes: notes,
    createdAt: DateTime.utc(2026, 9),
    pending: pending,
    deletedLocally: deletedLocally,
  );
}

OutboxRow _entry({
  required String op,
  required String clientUuid,
  int seq = 1,
}) {
  return OutboxRow(
    seq: seq,
    entity: 'herd_activity',
    op: op,
    clientUuid: clientUuid,
    attempts: 0,
    state: 'pending',
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  late AppDatabase db;
  late HerdActivityLocalDataSource local;
  late _FakeHerdActivityRemoteDataSource remote;
  late HerdActivitySyncer syncer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = HerdActivityLocalDataSource(db);
    remote = _FakeHerdActivityRemoteDataSource();
    syncer = HerdActivitySyncer(remote: remote, local: local);
  });

  tearDown(() async {
    await db.close();
  });

  test('entity is "herd_activity"', () {
    expect(syncer.entity, 'herd_activity');
  });

  test('hasCursor is false (never advances a pull cursor)', () {
    expect(syncer.hasCursor, isFalse);
  });

  group('push — create', () {
    test('calls remote.addHerdActivity(model.herdId, model) with the right '
        'herdId, then reconciles the server id via setServerId', () async {
      await local.upsert(
        _activity(clientUuid: 'cu-1', herdId: '42', count: 4),
        pending: true,
      );
      remote.responseBuilder = (herdId, model) => HerdActivityModel(
        id: 'server-99',
        herdId: herdId,
        activityType: model.activityType,
        count: model.count,
        date: model.date,
        notes: model.notes,
        createdAt: DateTime.utc(2026, 9, 6, 15, 30),
      );

      await syncer.push(
        _entry(op: 'create', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.herdIdCalls, ['42']);
      expect(remote.addedModels, hasLength(1));
      expect(remote.addedModels.single.clientUuid, 'cu-1');
      expect(remote.addedModels.single.activityType, 'birth');
      expect(remote.addedModels.single.count, 4);

      final row = await local.getByClientUuid('cu-1');
      expect(row, isNotNull);
      expect(row!.pending, isFalse);
      expect(row.id, 'server-99');

      final driftRow = await (db.select(
        db.herdActivities,
      )..where((r) => r.clientUuid.equals('cu-1'))).getSingle();
      expect(
        driftRow.updatedAt.isAtSameMomentAs(DateTime.utc(2026, 9, 6, 15, 30)),
        isTrue,
      );
    });

    test('is a no-op when the local row is gone (annihilated)', () async {
      await syncer.push(
        _entry(op: 'create', clientUuid: 'missing'),
        FkResolver(const {}),
      );

      expect(remote.addedModels, isEmpty);
    });

    test(
      'a NetworkException from addHerdActivity propagates (not swallowed)',
      () async {
        await local.upsert(_activity(clientUuid: 'cu-1'), pending: true);
        remote.throwOnAdd = NetworkException();

        await expectLater(
          syncer.push(
            _entry(op: 'create', clientUuid: 'cu-1'),
            FkResolver(const {}),
          ),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'a ServerException from addHerdActivity propagates (not swallowed)',
      () async {
        await local.upsert(_activity(clientUuid: 'cu-1'), pending: true);
        remote.throwOnAdd = const ServerException('bad request');

        await expectLater(
          syncer.push(
            _entry(op: 'create', clientUuid: 'cu-1'),
            FkResolver(const {}),
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });

  group('push — non-create ops', () {
    test('update is a no-op — herd_activity is create-only', () async {
      await local.upsert(
        _activity(clientUuid: 'cu-1', id: 'server-1'),
        pending: true,
      );

      await syncer.push(
        _entry(op: 'update', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.addedModels, isEmpty);
    });

    test('delete is a no-op — herd_activity is create-only', () async {
      await local.upsert(
        _activity(clientUuid: 'cu-1', id: 'server-1'),
        pending: true,
      );

      await syncer.push(
        _entry(op: 'delete', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.addedModels, isEmpty);
    });
  });

  group('pull', () {
    test('always returns null and never touches remote/local', () async {
      final cursor = await syncer.pull(null);

      expect(cursor, isNull);
      expect(remote.addedModels, isEmpty);
    });

    test('returns null even when given a prior cursor', () async {
      final cursor = await syncer.pull(DateTime.utc(2026));

      expect(cursor, isNull);
    });
  });
}
