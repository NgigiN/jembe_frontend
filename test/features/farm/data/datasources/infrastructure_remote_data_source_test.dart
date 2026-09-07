import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/infrastructure_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [InfrastructureRemoteDataSourceImpl]
/// sends/expects today — the R2-01 prerequisite.
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

InfrastructureModel _infrastructure({
  String id = '',
  String clientUuid = 'cu-1',
  String type = 'fence',
  String name = 'North Fence',
  String location = 'North Field',
  double cost = 5000,
  String notes = '',
}) {
  final now = DateTime.utc(2026);
  return InfrastructureModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    type: type,
    name: name,
    location: location,
    cost: cost,
    date: now,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getInfrastructures', () {
    test('GETs /api/v1/infrastructure and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","type":"fence","name":"North Fence", '
            '"location":"North Field","cost":5000,"notes":"barbed wire", '
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getInfrastructures();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/infrastructure');
      expect(result.single.cost, 5000);
      expect(result.single.notes, 'barbed wire');
    });

    test('a null response body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getInfrastructures(), isEmpty);
    });

    test('missing notes parses as an empty string, not null/a throw', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","type":"fence","name":"North Fence", '
            '"location":"North Field","cost":5000, '
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
      );
      final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getInfrastructures();

      expect(result.single.notes, '');
    });

    test('a connection failure throws NetworkException', () async {
      final source = InfrastructureRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getInfrastructures(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.getInfrastructures(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('addInfrastructure', () {
    test(
      'POSTs to /api/v1/infrastructure spreading toJson() plus client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","type":"fence","name":"North Fence", '
              '"location":"North Field","cost":5000,"notes":"", '
              '"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addInfrastructure(
          _infrastructure(clientUuid: 'cu-9'),
        );

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/infrastructure');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['client_uuid'], 'cu-9');
        expect(body['type'], 'fence');
        expect(body['cost'], 5000);
        expect(result.id, '9');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = InfrastructureRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addInfrastructure(_infrastructure()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('updateInfrastructure', () {
    test(
      'PUTs to /api/v1/infrastructure/:id sending toJson() with NO '
      'client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","type":"fence","name":"Renamed",'
              '"location":"North Field","cost":5000,"notes":"", '
              '"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateInfrastructure(
          _infrastructure(id: '9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/infrastructure/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(result.name, 'Renamed');
      },
    );
  });

  group('deleteInfrastructure', () {
    test('DELETEs /api/v1/infrastructure/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteInfrastructure('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/infrastructure/9');
    });

    test('a non-200/204 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = InfrastructureRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteInfrastructure('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
