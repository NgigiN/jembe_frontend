import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [PlantRemoteDataSourceImpl] sends/expects today —
/// the R2-01 prerequisite.
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

PlantModel _plant({
  String id = '',
  String clientUuid = 'cu-1',
  String name = 'Maize',
  String? variety,
}) {
  final now = DateTime.utc(2026);
  return PlantModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    variety: variety,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getPlants', () {
    test('GETs /api/v1/plants and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Maize","variety":"H614",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getPlants();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/plants');
      expect(result.single.name, 'Maize');
      expect(result.single.variety, 'H614');
    });

    test('a null response body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getPlants(), isEmpty);
    });

    test('a missing variety parses as null', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Beans",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
      );
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getPlants();

      expect(result.single.variety, isNull);
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getPlants(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getPlants(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test(
        'the initial fetch sends limit=500 but omits cursor '
        '(P3-02a, F3)', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getPlants(limit: 500);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('omits limit/cursor when neither is given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getPlants();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('a connection failure throws NetworkException', () async {
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(source.getPlants(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getPlants(), throwsA(isA<ServerException>()));
    });
  });

  group('addPlant', () {
    test(
      'POSTs to /api/v1/plants with a hand-built name/variety body plus '
      'client_uuid (NOT a toJson() spread)',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Maize","variety":"H614",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addPlant(
          _plant(clientUuid: 'cu-9', variety: 'H614'),
        );

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/plants');
        expect(adapter.lastOptions!.data, {
          'name': 'Maize',
          'variety': 'H614',
          'client_uuid': 'cu-9',
        });
        expect(result.id, '9');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(
        source.addPlant(_plant()),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-201 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 422);
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.addPlant(_plant()),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('updatePlant', () {
    test(
      'PUTs to /api/v1/plants/:id with name/variety only — no id/client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Renamed",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updatePlant(
          _plant(id: '9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/plants/9');
        expect(adapter.lastOptions!.data, {'name': 'Renamed', 'variety': null});
        expect(result.name, 'Renamed');
      },
    );
  });

  group('deletePlant', () {
    test('DELETEs /api/v1/plants/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deletePlant('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/plants/9');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = PlantRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deletePlant('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
