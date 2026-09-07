import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [AnimalRemoteDataSourceImpl] sends/expects today —
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

AnimalModel _animal({
  String id = '',
  String clientUuid = 'cu-1',
  String name = 'Bessie',
  String animalTypeId = '1',
  String herdId = '2',
  String? sex,
  String? acquisitionSource,
}) {
  final now = DateTime.utc(2026);
  return AnimalModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    animalTypeId: animalTypeId,
    herdId: herdId,
    birthDate: DateTime.utc(2025, 6),
    sex: sex,
    acquisitionSource: acquisitionSource,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getAnimals', () {
    test('GETs /api/v1/animals and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Bessie","animal_type_id":"1","herd_id":"2",'
            '"birth_date":"2025-06-01T00:00:00Z","sex":"female",'
            '"acquisition_source":"purchased",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getAnimals();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/animals');
      expect(result, hasLength(1));
      expect(result.single.name, 'Bessie');
      expect(result.single.sex, 'female');
      expect(result.single.acquisitionSource, 'purchased');
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getAnimals(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('a non-list body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getAnimals(), isEmpty);
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getAnimals(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test(
        'the initial fetch sends limit=500 but omits cursor '
        '(P3-02a, F3)', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getAnimals(limit: 500);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('omits limit/cursor when neither is given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getAnimals();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test(
      'nullable fields (sex/acquisition_source) missing from the response '
      'parse as null',
      () async {
        final adapter = _FakeAdapter(
          body:
              '[{"id":"2","name":"Bare","animal_type_id":"1","herd_id":"2",'
              '"birth_date":"2025-06-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
        );
        final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.getAnimals();

        expect(result.single.sex, isNull);
        expect(result.single.acquisitionSource, isNull);
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = AnimalRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(source.getAnimals(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getAnimals(), throwsA(isA<ServerException>()));
    });
  });

  group('addAnimal', () {
    test(
      'POSTs to /api/v1/animals spreading toJson() plus client_uuid, and '
      'FK ids are sent as ints when parseable',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Bessie","animal_type_id":"1","herd_id":"2",'
              '"birth_date":"2025-06-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addAnimal(
          _animal(
            clientUuid: 'cu-9',
            sex: 'female',
            acquisitionSource: 'purchased',
          ),
        );

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/animals');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body, {
          'name': 'Bessie',
          'animal_type_id': 1,
          'herd_id': 2,
          'birth_date': DateTime.utc(2025, 6).toUtc().toIso8601String(),
          'sex': 'female',
          'acquisition_source': 'purchased',
          'client_uuid': 'cu-9',
        });
        expect(result.id, '9');
      },
    );

    test(
      'an unsynced parent (non-numeric FK id) is sent through unchanged, '
      'not coerced to 0',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Bessie","animal_type_id":"1","herd_id":"2",'
              '"birth_date":"2025-06-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addAnimal(
          _animal(animalTypeId: 'unsynced-cu', herdId: 'unsynced-herd-cu'),
        );

        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['animal_type_id'], 'unsynced-cu');
        expect(body['herd_id'], 'unsynced-herd-cu');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = AnimalRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addAnimal(_animal()),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'a non-2xx response throws ServerException carrying the server message',
      () async {
        final adapter = _FakeAdapter(
          body: '{"error":"name is required"}',
          statusCode: 422,
        );
        final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.addAnimal(_animal()),
          throwsA(
            isA<ServerException>().having(
              (e) => e.message,
              'message',
              'name is required',
            ),
          ),
        );
      },
    );
  });

  group('updateAnimal', () {
    test(
      'PUTs to /api/v1/animals/:id sending toJson() with NO client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","name":"Renamed","animal_type_id":"1","herd_id":"2",'
              '"birth_date":"2025-06-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateAnimal(
          _animal(id: '9', name: 'Renamed'),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/animals/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(body['name'], 'Renamed');
        expect(result.name, 'Renamed');
      },
    );

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 404);
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.updateAnimal(_animal(id: '9')),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('deleteAnimal', () {
    test('DELETEs /api/v1/animals/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteAnimal('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/animals/9');
    });

    test('a 204 response is treated as success', () async {
      final adapter = _FakeAdapter(body: 'null', statusCode: 204);
      final source = AnimalRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.deleteAnimal('9'), completes);
    });

    test('a connection failure throws NetworkException', () async {
      final source = AnimalRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.deleteAnimal('9'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
