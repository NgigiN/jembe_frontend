import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [HerdRemoteDataSourceImpl] sends/expects today —
/// the R2-01 prerequisite. `current_head_count` is server-managed and
/// deliberately OMITTED from every outgoing body (see `HerdModel.toJson`
/// class docs) — pinned below so a generic `CrudDataSource` doesn't
/// accidentally start sending it.
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

HerdModel _herd({
  String id = '',
  String clientUuid = 'cu-1',
  String name = 'North Herd',
  String animalTypeId = '1',
  int initialHeadCount = 10,
  int currentHeadCount = 10,
  DateTime? endDate,
}) {
  final now = DateTime.utc(2026);
  return HerdModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    animalTypeId: animalTypeId,
    location: 'North Field',
    initialHeadCount: initialHeadCount,
    currentHeadCount: currentHeadCount,
    startDate: now,
    endDate: endDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getHerds', () {
    test('GETs /api/v1/herds and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"North Herd","animal_type_id":"1", '
            '"location":"North Field","initial_head_count":10, '
            '"current_head_count":8,"start_date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getHerds();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/herds');
      expect(result.single.currentHeadCount, 8);
    });

    test('a null response body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getHerds(), isEmpty);
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHerds(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHerds(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test(
        'the initial fetch sends limit=500 but omits cursor '
        '(P3-02a, F3)', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHerds(limit: 500);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('omits limit/cursor when neither is given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHerds();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('a connection failure throws NetworkException', () async {
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(source.getHerds(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getHerds(), throwsA(isA<ServerException>()));
    });
  });

  group('addHerd', () {
    test(
      'POSTs to /api/v1/herds spreading toJson() (current_head_count '
      'OMITTED) plus client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"North Herd","animal_type_id":"1", '
              '"location":"North Field","initial_head_count":10, '
              '"current_head_count":10,"start_date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addHerd(_herd(clientUuid: 'cu-9'));

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/herds');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(
          body.containsKey('current_head_count'),
          isFalse,
          reason: 'current_head_count is server-managed, never sent',
        );
        expect(body, {
          'name': 'North Herd',
          'animal_type_id': 1,
          'location': 'North Field',
          'initial_head_count': 10,
          'start_date': DateTime.utc(2026).toUtc().toIso8601String(),
          'end_date': null,
          'client_uuid': 'cu-9',
        });
        expect(result.id, '9');
      },
    );

    test(
      'an unsynced parent animal_type_id (non-numeric) is sent through '
      'unchanged, not coerced to 0',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"North Herd","animal_type_id":"1", '
              '"location":"North Field","initial_head_count":10, '
              '"current_head_count":10,"start_date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addHerd(_herd(animalTypeId: 'unsynced-cu'));

        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['animal_type_id'], 'unsynced-cu');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(
        source.addHerd(_herd()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('updateHerd', () {
    test(
      'PUTs to /api/v1/herds/:id sending toJson() — still omitting '
      'current_head_count, with NO client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Renamed","animal_type_id":"1",'
              '"location":"North Field","initial_head_count":10, '
              '"current_head_count":10,"start_date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateHerd(
          _herd(id: '9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/herds/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('current_head_count'), isFalse);
        expect(body.containsKey('client_uuid'), isFalse);
        expect(result.name, 'Renamed');
      },
    );
  });

  group('deleteHerd', () {
    test('DELETEs /api/v1/herds/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteHerd('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/herds/9');
    });

    test('a non-200/204 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = HerdRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteHerd('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
