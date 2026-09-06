import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/data/sync/herd_activity_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake [HerdActivityRemoteDataSource] that records the `herdId` argument it
/// was invoked with (so tests can assert whether the syncer sent the raw
/// client_uuid or the resolved server id) and returns a canned created model.
class _FakeHerdActivityRemoteDataSource
    implements HerdActivityRemoteDataSource {
  String? lastHerdId;
  HerdActivityModel? lastAdded;
  String createdId = '500';

  @override
  Future<HerdActivityModel> addHerdActivity(
    String herdId,
    HerdActivityModel activity,
  ) async {
    lastHerdId = herdId;
    lastAdded = activity;
    return HerdActivityModel(
      id: createdId,
      herdId: herdId,
      activityType: activity.activityType,
      count: activity.count,
      date: activity.date,
      notes: activity.notes,
      createdAt: DateTime.utc(2026, 9, 6, 12),
    );
  }
}

/// A [HttpClientAdapter] that never touches the network: records the
/// [RequestOptions] it was given (so a test can inspect the raw request
/// body) and returns a canned JSON response.
class _RecordingHttpAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  Map<String, dynamic> responseJson = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(responseJson),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

HerdActivityModel _activity({
  required String clientUuid,
  required String herdId,
  String id = '',
  String activityType = 'birth',
  int count = 1,
  DateTime? date,
  String? notes,
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
  );
}

OutboxRow createRow(String clientUuid) {
  return OutboxRow(
    seq: 1,
    entity: 'herd_activity',
    op: 'create',
    clientUuid: clientUuid,
    attempts: 0,
    state: 'pending',
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  group('HerdActivitySyncer.push — herd FK translation', () {
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

    test(
      'translates the herd client_uuid to its server id for the nested URL',
      () async {
        await local.upsert(
          _activity(clientUuid: 'ha-uuid', herdId: 'herd-uuid'),
          pending: true,
        );
        final resolver = FkResolver(const {})..record('herd', 'herd-uuid', '77');

        await syncer.push(createRow('ha-uuid'), resolver);

        expect(remote.lastHerdId, '77'); // URL got the SERVER id, not the uuid
        expect(
          await resolver.resolve('herd_activity', 'ha-uuid'),
          '500',
        ); // created id recorded on the resolver

        final row = await local.getByClientUuid('ha-uuid');
        expect(row, isNotNull);
        expect(row!.id, '500'); // setServerId reconciled the local row
        expect(row.pending, isFalse);
      },
    );

    test(
      'parks (throws SyncDependencyException) when the herd is unsynced',
      () async {
        await local.upsert(
          _activity(clientUuid: 'ha-uuid', herdId: 'herd-uuid'),
          pending: true,
        );
        final resolver = FkResolver(const {}); // herd not recorded anywhere

        await expectLater(
          syncer.push(createRow('ha-uuid'), resolver),
          throwsA(isA<SyncDependencyException>()),
        );

        expect(remote.lastAdded, isNull, reason: 'must not call remote before resolving the FK');
        final row = await local.getByClientUuid('ha-uuid');
        expect(row!.pending, isTrue, reason: 'parked row stays pending, unreconciled');
      },
    );

    test('an already-numeric herdId (already-synced herd) needs no resolver record', () async {
      await local.upsert(
        _activity(clientUuid: 'ha-uuid', herdId: '77'),
        pending: true,
      );
      final resolver = FkResolver(const {}); // no 'herd' store, no record

      await syncer.push(createRow('ha-uuid'), resolver);

      expect(remote.lastHerdId, '77');
    });
  });

  group('HerdActivityRemoteDataSourceImpl.addHerdActivity — create body', () {
    test('POST body spreads client_uuid alongside toJson (idempotency key)', () async {
      final adapter = _RecordingHttpAdapter()
        ..responseJson = {
          'id': '500',
          'herd_id': '77',
          'activity_type': 'birth',
          'count': 2,
          'date': DateTime.utc(2026, 9, 6).toIso8601String(),
          'reason': '',
          'created_at': DateTime.utc(2026, 9, 6).toIso8601String(),
        };
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter;
      final remoteDataSource = HerdActivityRemoteDataSourceImpl(dio: dio);
      final activity = HerdActivityModel.create(
        herdId: '77',
        activityType: 'birth',
        count: 2,
        date: DateTime.utc(2026, 9, 6),
        clientUuid: 'ha-body-uuid',
      );

      await remoteDataSource.addHerdActivity('77', activity);

      final sentBody = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(sentBody, {...activity.toJson(), 'client_uuid': 'ha-body-uuid'});
      expect(adapter.lastOptions!.path, '/api/v1/herds/77/activities');
    });
  });
}
