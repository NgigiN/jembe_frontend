import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [AnalysisRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite. Unlike every other farm datasource,
/// this one is READ-ONLY (no create/update/delete). It used to carry an
/// extra 401/403 branch meant to throw a canned "Authentication
/// required..." [ServerException], but that branch was unreachable dead
/// code (Dio's default validateStatus rejects any non-2xx before the
/// if/else chain that checked response.statusCode ever ran, so
/// `on DioException catch (e)` always won first) and was removed in F1-05.
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

void main() {
  group('getTotalCostsBySeason', () {
    test('GETs /api/v1/analytics/total-costs and parses the response', () async {
      final adapter = _FakeAdapter(
        body:
            '{"details":[{"type":"season","id":1,"name":"Long Rains", '
            '"category":"plant","location":"North Field", '
            '"start_date":"2026-01-01T00:00:00Z","input_cost":100,'
            '"activity_cost":50,"total_cost":150}]}',
      );
      final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getTotalCostsBySeason();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/analytics/total-costs');
      expect(result.details, hasLength(1));
      expect(result.details.single.totalCost, 150);
      expect(result.details.single.endDate, isNull);
    });

    test(
      'a 401 throws ServerException via the generic DioException branch '
      '(the now-removed dead 401/403 branch never fired)',
      () async {
        final adapter = _FakeAdapter(body: '{}', statusCode: 401);
        final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.getTotalCostsBySeason(),
          throwsA(
            isA<ServerException>().having((e) => e.message, 'message', isNull),
          ),
        );
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = AnalysisRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getTotalCostsBySeason(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-200/401/403 response throws ServerException with the server message', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.getTotalCostsBySeason(),
        throwsA(
          isA<ServerException>().having((e) => e.message, 'message', 'boom'),
        ),
      );
    });
  });

  group('getCostBreakdownByInputType', () {
    test('GETs /api/v1/analytics/cost-breakdown and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"category":"Seeds","type":"plant","origin":"Long Rains 2026", '
            '"origin_id":"5","origin_type":"season","total_cost":500,'
            '"percentage":60}]',
      );
      final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getCostBreakdownByInputType();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/analytics/cost-breakdown');
      expect(result.single.originId, '5');
      expect(result.single.originType, 'season');
    });

    test('a null response body parses as an empty list', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

      expect(await source.getCostBreakdownByInputType(), isEmpty);
    });

    test('a connection failure throws NetworkException', () async {
      final source = AnalysisRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getCostBreakdownByInputType(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('getAnnualCostSummary', () {
    test(
      'GETs /api/v1/analytics/monthly-summary with date-only start/end '
      'query params and parses each row',
      () async {
        final adapter = _FakeAdapter(
          body:
              '[{"month":"2026-01","total_costs":100,"total_revenue":200,'
              '"profit":100,"breakdown":{"costs":{"plant":50,"animal":50,'
              '"infrastructure":0},"revenue":{"plant":150,"animal":50}}}]',
        );
        final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.getAnnualCostSummary(
          DateTime.utc(2026),
          DateTime.utc(2026, 12, 31),
        );

        expect(adapter.lastOptions!.method, 'GET');
        expect(
          adapter.lastOptions!.path,
          '/api/v1/analytics/monthly-summary',
        );
        final params = adapter.lastOptions!.uri.queryParameters;
        expect(params['start_date'], '2026-01-01');
        expect(params['end_date'], '2026-12-31');
        expect(result.single.profit, 100);
        expect(result.single.breakdown.costs.plant, 50);
      },
    );

    test(
      'a missing breakdown falls back to zeroed cost/revenue breakdowns',
      () async {
        final adapter = _FakeAdapter(
          body:
              '[{"month":"2026-01","total_costs":0,"total_revenue":0,'
              '"profit":0}]',
        );
        final source = AnalysisRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.getAnnualCostSummary(
          DateTime.utc(2026),
          DateTime.utc(2026, 1, 31),
        );

        expect(result.single.breakdown.costs.plant, 0);
        expect(result.single.breakdown.revenue.animal, 0);
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = AnalysisRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getAnnualCostSummary(DateTime.utc(2026), DateTime.utc(2026, 2)),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
