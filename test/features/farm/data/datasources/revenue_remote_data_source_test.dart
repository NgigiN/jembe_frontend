import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [RevenueRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite. `total` is the flagship per-entity
/// quirk here: `RevenueModel.toJson()` sends it ONLY when `> 0` (see the
/// `addRevenue` group below) — the server derives `quantity * unit_price`
/// itself otherwise.
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

RevenueModel _revenue({
  String id = '',
  String clientUuid = 'cu-1',
  String source = 'harvest',
  String sourceId = '1',
  double quantity = 10,
  double unitPrice = 50,
  double? total,
  String? notes,
}) {
  final now = DateTime.utc(2026);
  return RevenueModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    source: source,
    sourceId: sourceId,
    type: 'milk',
    quantity: quantity,
    unitPrice: unitPrice,
    total: total ?? quantity * unitPrice,
    date: now,
    notes: notes,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('getRevenues', () {
    test('GETs /api/v1/revenue and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","source":"harvest","source_id":"1","type":"milk",'
            '"quantity":10,"unit_price":50,"total":500,'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}]',
      );
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getRevenues();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/revenue');
      expect(result.single.total, 500);
    });

    test('a null response body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getRevenues(), isEmpty);
    });

    test(
      'sends scope/start_date/end_date/updated_since as query params',
      () async {
        final adapter = _FakeAdapter(body: '[]');
        final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.getRevenues(
          scope: const AnalyticsScope.land('7'),
          startDate: DateTime.utc(2026),
          endDate: DateTime.utc(2026, 1, 31),
          updatedSince: DateTime.utc(2026, 3, 4),
        );

        final params = adapter.lastOptions!.uri.queryParameters;
        expect(params['source'], 'plant');
        expect(params['land_id'], '7');
        expect(params['start_date'], '2026-01-01');
        expect(params['end_date'], '2026-01-31');
        expect(params['updated_since'], '2026-03-04T00:00:00.000Z');
      },
    );

    test(
      'sends limit and cursor as query params when given (P3-02a)',
      () async {
        final adapter = _FakeAdapter(body: '[]');
        final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.getRevenues(limit: 500, cursor: 42);

        final params = adapter.lastOptions!.uri.queryParameters;
        expect(params['limit'], '500');
        expect(params['cursor'], '42');
      },
    );

    test('the initial fetch sends limit=500 but omits cursor '
        '(P3-02a, F3)', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getRevenues(limit: 500);

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params['limit'], '500');
      expect(params.containsKey('cursor'), isFalse);
    });

    test('omits limit/cursor when neither is given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getRevenues();

      final params = adapter.lastOptions!.uri.queryParameters;
      expect(params.containsKey('limit'), isFalse);
      expect(params.containsKey('cursor'), isFalse);
    });

    test('a connection failure throws NetworkException', () async {
      final source = RevenueRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(source.getRevenues(), throwsA(isA<NetworkException>()));
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.getRevenues(), throwsA(isA<ServerException>()));
    });
  });

  group('getRevenueById', () {
    test('GETs /api/v1/revenue/:id', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"1","source":"harvest","source_id":"1","type":"milk",'
            '"quantity":10,"unit_price":50,"total":500,'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
      );
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getRevenueById('1');

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/revenue/1');
      expect(result.id, '1');
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 404);
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.getRevenueById('1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('addRevenue', () {
    test('POSTs to /api/v1/revenue spreading toJson() plus client_uuid; '
        '"total" is INCLUDED when > 0', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","source":"harvest","source_id":"1","type":"milk",'
            '"quantity":10,"unit_price":50,"total":500,'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.addRevenue(
        _revenue(clientUuid: 'cu-9', total: 500),
      );

      expect(adapter.lastOptions!.method, 'POST');
      expect(adapter.lastOptions!.path, '/api/v1/revenue');
      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body['total'], 500);
      expect(body['client_uuid'], 'cu-9');
      expect(result.id, '9');
    });

    test('"total" is OMITTED from the body when it is 0 (the flagship quirk '
        "R2-01's toRequestBody override must preserve)", () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","source":"harvest","source_id":"1","type":"milk",'
            '"quantity":0,"unit_price":0,"total":0,'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.addRevenue(_revenue(quantity: 0, unitPrice: 0, total: 0));

      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body.containsKey('total'), isFalse);
    });

    test('"notes" is OMITTED from the body when null or empty', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","source":"harvest","source_id":"1","type":"milk",'
            '"quantity":10,"unit_price":50,"total":500,'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.addRevenue(_revenue(notes: ''));

      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body.containsKey('notes'), isFalse);
    });

    test('a non-empty "notes" IS included in the body', () async {
      final adapter = _FakeAdapter(
        body:
            '{"id":"9","source":"harvest","source_id":"1","type":"milk",'
            '"quantity":10,"unit_price":50,"total":500,'
            '"date":"2026-01-01T00:00:00Z",'
            '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        statusCode: 201,
      );
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.addRevenue(_revenue(notes: 'sold at market'));

      final body = adapter.lastOptions!.data as Map<String, dynamic>;
      expect(body['notes'], 'sold at market');
    });

    test('a connection failure throws NetworkException', () async {
      final source = RevenueRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addRevenue(_revenue()),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('updateRevenue', () {
    test(
      'PUTs to /api/v1/revenue/:id sending toJson() with NO client_uuid',
      () async {
        final adapter = _FakeAdapter(
          body:
              '{"id":"9","source":"harvest","source_id":"1","type":"milk",'
              '"quantity":20,"unit_price":50,"total":1000,'
              '"date":"2026-01-01T00:00:00Z",'
              '"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}',
        );
        final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.updateRevenue(
          _revenue(id: '9', quantity: 20),
        );

        expect(adapter.lastOptions!.method, 'PUT');
        expect(adapter.lastOptions!.path, '/api/v1/revenue/9');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body.containsKey('client_uuid'), isFalse);
        expect(result.quantity, 20);
      },
    );
  });

  group('deleteRevenue', () {
    test('DELETEs /api/v1/revenue/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteRevenue('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/revenue/9');
    });

    test('a 204 response is treated as success', () async {
      final adapter = _FakeAdapter(body: 'null', statusCode: 204);
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(source.deleteRevenue('9'), completes);
    });

    test('a non-200/204 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = RevenueRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteRevenue('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
