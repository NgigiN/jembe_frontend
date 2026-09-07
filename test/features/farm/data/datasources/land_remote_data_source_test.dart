import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [LandRemoteDataSourceImpl] sends/expects today —
/// the R2-01 prerequisite: a generic `CrudDataSource` swapped in later must
/// reproduce every method/path/body assertion below byte for byte.
///
/// Fake [HttpClientAdapter] that returns a canned body/status without
/// touching the network, and records the [RequestOptions] it was called
/// with so tests can assert on method/path/body. Mirrors the pattern in
/// `test/core/sync/deletions_data_source_test.dart`.
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

/// Fake adapter that simulates a connection failure (offline).
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

LandModel _land({
  String id = '',
  String clientUuid = 'cu-1',
  String name = 'North Field',
  double? size,
  String? location,
  String? soilType,
  String? tenureType,
}) {
  final now = DateTime.utc(2026);
  return LandModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    size: size,
    location: location,
    soilType: soilType,
    tenureType: tenureType,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getLands', () {
    test('GETs /api/v1/lands and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"North Field","size":2.5,"location":"Nyeri", '
            '"soil_type":"loam","tenure_type":"owned",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getLands();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/lands');
      expect(result, hasLength(1));
      expect(result.single.name, 'North Field');
      expect(result.single.size, 2.5);
      expect(result.single.tenureType, 'owned');
      expect(result.single.updatedAt, DateTime.utc(2026, 1, 2));
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getLands(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('omits the query param when updatedSince is null', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getLands();

      expect(
        adapter.lastOptions!.uri.queryParameters.containsKey('updated_since'),
        isFalse,
      );
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getLands(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test(
        'the initial fetch sends limit=500 but omits cursor '
        '(P3-02a, F3)', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getLands(limit: 500);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('omits limit/cursor when neither is given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getLands();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('a non-list 200 body (e.g. null) parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getLands();

      expect(result, isEmpty);
    });

    test(
      'nullable fields (size/location/soil_type/tenure_type) missing from '
      'the response parse as null, not a throw',
      () async {
        final adapter = _FakeAdapter(
          body:
              '[{"id":"2","name":"Bare Plot", '
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
        );
        final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.getLands();

        expect(result.single.size, isNull);
        expect(result.single.location, isNull);
        expect(result.single.soilType, isNull);
        expect(result.single.tenureType, isNull);
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = LandRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(source.getLands(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getLands(), throwsA(isA<ServerException>()));
    });
  });

  group('addLand', () {
    test(
      'POSTs to /api/v1/lands with the field-mapped body plus a spread '
      'client_uuid, and parses the 201 response',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"North Field","size":2.5,"location":"Nyeri", '
              '"soil_type":"loam","tenure_type":"owned",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addLand(
          _land(
            clientUuid: 'cu-9',
            size: 2.5,
            location: 'Nyeri',
            soilType: 'loam',
            tenureType: 'owned',
          ),
        );

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/lands');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body, {
          'name': 'North Field',
          'size': 2.5,
          'location': 'Nyeri',
          'soil_type': 'loam',
          'tenure_type': 'owned',
          'client_uuid': 'cu-9',
        }, reason: 'client_uuid rides alongside the field-mapped body');
        expect(result.id, '9');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = LandRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(
        source.addLand(_land()),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-201 response throws ServerException carrying the server message', () async {
      final adapter = _FakeAdapter(
        body: '{"error":"name is required"}',
        statusCode: 422,
      );
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.addLand(_land()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'name is required',
          ),
        ),
      );
    });
  });

  group('updateLand', () {
    test(
      'PUTs to /api/v1/lands/:id with the field-mapped body and NO '
      'client_uuid (update never spreads it)',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Renamed","created_at":"2026-01-01T00:00:00Z",'
              '"updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateLand(
          _land(id: '9', clientUuid: 'cu-9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/lands/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(body['name'], 'Renamed');
        expect(result.name, 'Renamed');
      },
    );

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 404);
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.updateLand(_land(id: '9')),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('deleteLand', () {
    test('DELETEs /api/v1/lands/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteLand('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/lands/9');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = LandRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteLand('9'),
        throwsA(isA<ServerException>()),
      );
    });

    test('a connection failure throws NetworkException', () async {
      final source = LandRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(
        source.deleteLand('9'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
