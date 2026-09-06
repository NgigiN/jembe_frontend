import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [HerdActivityRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite. This is the one farm entity whose create
/// URL is NESTED (`/herds/:herdId/activities`, `herdId` a separate method
/// arg, not part of the body) and whose `notes` field travels under the
/// backend name `reason`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.body, this.statusCode = 200});
  final String body;
  final int statusCode;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated offline',
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
}

HerdActivityModel _activity({
  String herdId = 'herd-1',
  String activityType = 'birth',
  int count = 1,
  String? notes,
}) {
  return HerdActivityModel.create(
    herdId: herdId,
    activityType: activityType,
    count: count,
    date: DateTime.utc(2026, 9),
    notes: notes,
  );
}

void main() {
  group('addHerdActivity', () {
    test(
      'POSTs to the NESTED /api/v1/herds/:herdId/activities URL, sending '
      'toJson() (herdId omitted, notes under "reason") plus client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"ID":"9","herd_id":"1","activity_type":"birth","count":2,'
              '"date":"2026-09-01T00:00:00Z","reason":"twins",'
              '"CreatedAt":"2026-09-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = HerdActivityRemoteDataSourceImpl(dio: _dioWith(adapter));

        final model = _activity(count: 2, notes: 'twins');

        final result = await source.addHerdActivity('herd-1', model);

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/herds/herd-1/activities');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('herd_id'), isFalse);
        expect(body.containsKey('notes'), isFalse);
        expect(body, {
          'activity_type': 'birth',
          'count': 2,
          'date': DateTime.utc(2026, 9).toIso8601String(),
          'reason': 'twins',
          'client_uuid': model.clientUuid,
        });
        expect(result.notes, 'twins');
      },
    );

    test('a 200 response (not just 201) is also treated as success', () async {
      final adapter = _FakeAdapter(
        body:
            '{"ID":"9","herd_id":"1","activity_type":"fatality","count":1,'
            '"date":"2026-09-01T00:00:00Z","reason":"",'
            '"CreatedAt":"2026-09-01T00:00:00Z"}',
      );
      final source = HerdActivityRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.addHerdActivity('herd-1', _activity(activityType: 'fatality')),
        completes,
      );
    });

    test(
      'a null notes on create sends reason: "" (never omits the key)',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"ID":"9","herd_id":"1","activity_type":"birth","count":1,'
              '"date":"2026-09-01T00:00:00Z","reason":"",'
              '"CreatedAt":"2026-09-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = HerdActivityRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addHerdActivity('herd-1', _activity());

        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['reason'], '');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = HerdActivityRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addHerdActivity('herd-1', _activity()),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'a non-2xx response throws ServerException carrying the server message',
      () async {
        final adapter = _FakeAdapter(
          body: '{"error":"herd not found"}',
          statusCode: 404,
        );
        final source = HerdActivityRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.addHerdActivity('herd-1', _activity()),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'herd not found',
            ),
          ),
        );
      },
    );
  });
}
