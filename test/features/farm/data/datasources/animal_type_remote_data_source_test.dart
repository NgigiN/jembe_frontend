import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_type_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [AnimalTypeRemoteDataSourceImpl] sends/expects
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

AnimalTypeModel _animalType({
  String id = '',
  String clientUuid = 'cu-1',
  String name = 'Dairy Cow',
  String? notes,
}) {
  final now = DateTime.utc(2026);
  return AnimalTypeModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getAnimalTypes', () {
    test('GETs /api/v1/animal-types and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Dairy Cow","notes":"good milker", '
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getAnimalTypes();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/animal-types');
      expect(result.single.name, 'Dairy Cow');
      expect(result.single.notes, 'good milker');
    });

    test('a null response body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getAnimalTypes(), isEmpty);
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getAnimalTypes(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('a connection failure throws NetworkException', () async {
      final source = AnimalTypeRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getAnimalTypes(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('getAnimalType (singular)', () {
    test('GETs /api/v1/animal-types/:id', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"1","name":"Dairy Cow", '
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
      );
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getAnimalType('1');

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/animal-types/1');
      expect(result.name, 'Dairy Cow');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 404);
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.getAnimalType('1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('addAnimalType', () {
    test(
      'POSTs to /api/v1/animal-types spreading toJson() (notes omitted '
      'when blank) plus client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Dairy Cow", '
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addAnimalType(_animalType(clientUuid: 'cu-9'));

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/animal-types');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body, {'name': 'Dairy Cow', 'client_uuid': 'cu-9'});
      },
    );

    test('a non-blank notes IS included in the body', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","name":"Dairy Cow", '
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.addAnimalType(_animalType(notes: 'good milker'));

      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body['notes'], 'good milker');
    });

    test('a connection failure throws NetworkException', () async {
      final source = AnimalTypeRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addAnimalType(_animalType()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('updateAnimalType', () {
    test(
      'PUTs to /api/v1/animal-types/:id sending toJson() with NO '
      'client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Renamed",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateAnimalType(
          _animalType(id: '9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/animal-types/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(result.name, 'Renamed');
      },
    );
  });

  group('deleteAnimalType', () {
    test('DELETEs /api/v1/animal-types/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteAnimalType('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/animal-types/9');
    });

    test('a non-200/204 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = AnimalTypeRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteAnimalType('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
