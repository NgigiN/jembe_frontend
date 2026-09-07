import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [HarvestRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite.
///
/// R2-01 (F1-08 finding #6) fixed the quirk previously pinned here: this
/// datasource used to convert every `DioException` straight to
/// [ServerException], even a connection/timeout error — unlike every other
/// farm datasource, which routes through `mapDioException`. It now routes
/// through `mapDioException` too, so a connection failure surfaces as
/// [NetworkException] (see the "a connection failure" tests below).
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

HarvestModel _harvest({
  String id = '',
  String clientUuid = 'cu-1',
  String seasonId = '1',
  double quantity = 10,
  String unit = 'kg',
  String? revenueId,
}) {
  final now = DateTime.utc(2026);
  return HarvestModel(
    id: id,
    clientUuid: clientUuid,
    seasonId: seasonId,
    quantity: quantity,
    unit: unit,
    date: now,
    createdAt: now,
    updatedAt: now,
    revenueId: revenueId,
  );
}

void main() {
  group('getHarvests', () {
    test('GETs /api/v1/harvests and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","season_id":"1","quantity":10,"unit":"kg",'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getHarvests();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/harvests');
      expect(result.single.quantity, 10);
      expect(result.single.revenueId, isNull);
    });

    test('sends seasonId as a query param only when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHarvests(seasonId: '5');

      expect(adapter.lastOptions!.uri.queryParameters['season_id'], '5');
    });

    test('sends limit and cursor as query params when given (P3-02a)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHarvests(limit: 500, cursor: 42);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params['cursor'], '42');
    });

    test('omits limit/cursor when not given (unchanged one-shot request)',
        () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHarvests();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('sends updatedSince as an RFC3339 query param when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getHarvests(updatedSince: DateTime.utc(2026, 3, 4));

      expect(
        adapter.lastOptions!.uri.queryParameters['updated_since'],
        '2026-03-04T00:00:00.000Z',
      );
    });

    test('a revenue_id of 0 parses as null (no linked revenue)', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","season_id":"1","quantity":10,"unit":"kg",'
            '"revenue_id":0,"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}]',
      );
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getHarvests();

      expect(result.single.revenueId, isNull);
    });

    test(
      'a connection failure throws NetworkException (routes through '
      'mapDioException — R2-01 fix, see class docs)',
      () async {
        final source = HarvestRemoteDataSourceImpl(
          dio: _dioWith(_ThrowingAdapter()),
        );

        await expectLater(
          source.getHarvests(),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getHarvests(), throwsA(isA<ServerException>()));
    });
  });

  group('addHarvest', () {
    test(
      'POSTs to /api/v1/harvests spreading toJson() plus client_uuid; '
      'revenue_id is OMITTED when null',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","season_id":"1","quantity":10,"unit":"kg",'
              '"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
          statusCode: 201,
        );
        final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addHarvest(_harvest(clientUuid: 'cu-9'));

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/harvests');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('revenue_id'), isFalse);
        expect(body['client_uuid'], 'cu-9');
        expect(body['season_id'], 1);
        expect(result.id, '9');
      },
    );

    test('a non-null revenueId IS included in the body', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","season_id":"1","quantity":10,"unit":"kg",'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.addHarvest(_harvest(revenueId: '7'));

      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body['revenue_id'], 7);
    });

    test(
      'a connection failure throws NetworkException (routes through '
      'mapDioException — R2-01 fix)',
      () async {
        final source = HarvestRemoteDataSourceImpl(
          dio: _dioWith(_ThrowingAdapter()),
        );

        await expectLater(
          source.addHarvest(_harvest()),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('a non-201 response throws ServerException with the server message', () async {
      final adapter = _FakeAdapter(
        body: '{"error":"quantity is required"}',
        statusCode: 422,
      );
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.addHarvest(_harvest()),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'quantity is required',
          ),
        ),
      );
    });
  });

  group('updateHarvest', () {
    test('PUTs to /api/v1/harvests/:id sending toJson()', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","season_id":"1","quantity":20,"unit":"kg",'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
      );
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.updateHarvest(
        _harvest(id: '9', quantity: 20),
      );

      expect(adapter.lastOptions!.method, 'PUT');
      expect(adapter.lastOptions!.path, '/api/v1/harvests/9');
      expect(result.quantity, 20);
    });
  });

  group('deleteHarvest', () {
    test('DELETEs /api/v1/harvests/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteHarvest('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/harvests/9');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = HarvestRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteHarvest('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
