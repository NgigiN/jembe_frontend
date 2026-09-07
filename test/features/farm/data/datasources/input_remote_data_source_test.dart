import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [InputRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite. `animal_id` is the flagship per-entity
/// quirk here: OMITTED from the body when null or 0 (see the `addInput`/
/// `updateInput` groups below).
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

InputModel _input({
  String id = '',
  String clientUuid = 'cu-1',
  String sourceType = 'plant',
  String sourceId = '1',
  int? animalId,
  double cost = 100,
  double? quantity,
  String? notes,
}) {
  final now = DateTime.utc(2026);
  return InputModel(
    id: id,
    clientUuid: clientUuid,
    sourceType: sourceType,
    sourceId: sourceId,
    animalId: animalId,
    type: 'fertilizer',
    quantity: quantity,
    cost: cost,
    date: now,
    createdAt: now,
    updatedAt: now,
    notes: notes,
  );
}

void main() {
  group('getInputs', () {
    test('GETs /api/v1/inputs and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","source_type":"plant","source_id":"1","type":"fertilizer",'
            '"cost":100,"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getInputs();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/inputs');
      expect(result.single.cost, 100);
      expect(result.single.animalId, isNull);
    });

    test('an animal_id of 0 parses as null', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","source_type":"animal","source_id":"1","animal_id":0,'
            '"type":"feed","cost":100,"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
      );
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getInputs();

      expect(result.single.animalId, isNull);
    });

    test('sends sourceType as a query param only when non-empty', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getInputs(sourceType: 'plant');

      expect(adapter.lastOptions!.uri.queryParameters['source_type'], 'plant');
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getInputs(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test('omits limit/cursor when not given (unchanged one-shot request)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getInputs();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('a null response body (missing List) parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getInputs(), isEmpty);
    });

    test('a connection failure throws NetworkException', () async {
      final source = InputRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(source.getInputs(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getInputs(), throwsA(isA<ServerException>()));
    });
  });

  group('addInput', () {
    test(
      'POSTs to /api/v1/inputs with a hand-built body plus client_uuid; '
      'animal_id is OMITTED when null',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","source_type":"plant","source_id":"1","type":"fertilizer",'
              '"cost":100,"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addInput(_input(clientUuid: 'cu-9'));

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/inputs');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('animal_id'), isFalse);
        expect(body['client_uuid'], 'cu-9');
        expect(body['source_id'], 1);
        expect(result.id, '9');
      },
    );

    test(
      'animal_id is OMITTED when 0, and INCLUDED when a real non-zero id',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","source_type":"animal","source_id":"1","type":"feed",'
              '"cost":100,"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addInput(_input(animalId: 0));
        expect(
          (adapter.lastOptions!.data as Map<String, dynamic>).containsKey(
            'animal_id',
          ),
          isFalse,
        );

        await source.addInput(_input(animalId: 5));
        expect(
          (adapter.lastOptions!.data as Map<String, dynamic>)['animal_id'],
          5,
        );
      },
    );

    test('an unsynced parent source_id (non-numeric) is coerced to 0', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","source_type":"plant","source_id":"1","type":"fertilizer",'
            '"cost":100,"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.addInput(_input(sourceId: 'unsynced-plant-cu'));

      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body['source_id'], 0);
    });

    test('a connection failure throws NetworkException', () async {
      final source = InputRemoteDataSourceImpl(dio: _dioWith(_ThrowingAdapter()));

      await expectLater(
        source.addInput(_input()),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-201 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 422);
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.addInput(_input()),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('updateInput', () {
    test(
      'PUTs to /api/v1/inputs/:id with the same hand-built body and NO '
      'client_uuid; animal_id is still conditional',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","source_type":"plant","source_id":"1","type":"fertilizer",'
              '"cost":200,"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateInput(
          _input(id: '9', cost: 200),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/inputs/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(body.containsKey('animal_id'), isFalse);
        expect(result.cost, 200);
      },
    );
  });

  group('deleteInput', () {
    test('DELETEs /api/v1/inputs/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteInput('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/inputs/9');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = InputRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteInput('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
