import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [SeasonRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite.
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

SeasonModel _season({
  String id = '',
  String clientUuid = 'cu-1',
  String name = 'Long Rains 2026',
  String plantId = '1',
  String landId = '2',
  DateTime? endDate,
}) {
  final now = DateTime.utc(2026);
  return SeasonModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    plantId: plantId,
    landId: landId,
    startDate: now,
    endDate: endDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getSeasons', () {
    test('GETs /api/v1/seasons and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Long Rains 2026","plant_id":"1","land_id":"2", '
            '"start_date":"2026-03-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getSeasons();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/seasons');
      expect(result.single.name, 'Long Rains 2026');
      expect(result.single.endDate, isNull);
    });

    test(
      'an empty-string end_date parses as null, not a DateTime.parse throw',
      () async {
        final adapter = _FakeAdapter(
          body:
              '[{"id":"1","name":"Long Rains 2026","plant_id":"1","land_id":"2", '
              '"start_date":"2026-03-01T00:00:00Z","end_date":"",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
        );
        final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.getSeasons();

        expect(result.single.endDate, isNull);
      },
    );

    test('a present end_date parses correctly', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Long Rains 2026","plant_id":"1","land_id":"2", '
            '"start_date":"2026-03-01T00:00:00Z","end_date":"2026-06-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
      );
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getSeasons();

      expect(result.single.endDate, DateTime.utc(2026, 6));
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getSeasons(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getSeasons(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test(
        'the initial fetch sends limit=500 but omits cursor '
        '(P3-02a, F3)', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getSeasons(limit: 500);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('omits limit/cursor when neither is given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getSeasons();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('a connection failure throws NetworkException', () async {
      final source = SeasonRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(source.getSeasons(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getSeasons(), throwsA(isA<ServerException>()));
    });
  });

  group('addSeason', () {
    test(
      'POSTs to /api/v1/seasons with a hand-built body plus client_uuid; '
      'plant_id/land_id are sent as parsed ints',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Long Rains 2026","plant_id":"1","land_id":"2", '
              '"start_date":"2026-03-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addSeason(_season(clientUuid: 'cu-9'));

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/seasons');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['plant_id'], 1);
        expect(body['land_id'], 2);
        expect(body['client_uuid'], 'cu-9');
        expect(result.id, '9');
      },
    );

    test(
      'an unsynced parent (non-numeric FK id) is coerced to 0 — UNLIKE '
      "animal's FK handling, which preserves the raw string (pinned quirk "
      'the R2-01 CrudDataSource must decide whether to normalize)',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Long Rains 2026","plant_id":"1","land_id":"2", '
              '"start_date":"2026-03-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addSeason(
          _season(plantId: 'unsynced-plant-cu', landId: 'unsynced-land-cu'),
        );

        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['plant_id'], 0);
        expect(body['land_id'], 0);
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = SeasonRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addSeason(_season()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('updateSeason', () {
    test(
      'PUTs to /api/v1/seasons/:id with the hand-built body and NO '
      'client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Renamed","plant_id":"1","land_id":"2",'
              '"start_date":"2026-03-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateSeason(
          _season(id: '9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/seasons/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(result.name, 'Renamed');
      },
    );
  });

  group('deleteSeason', () {
    test('DELETEs /api/v1/seasons/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteSeason('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/seasons/9');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = SeasonRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteSeason('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
