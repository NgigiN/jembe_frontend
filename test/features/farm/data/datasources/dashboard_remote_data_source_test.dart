import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/dashboard_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [DashboardRemoteDataSourceImpl] sends/expects for
/// `GET /api/v1/dashboard` (Phase 8 A1/B1) — a fresh, snake_case-only
/// endpoint (no dual `ID`/`id` key tolerance needed, unlike the older farm
/// datasources).
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

const _fullBody = '''
{
  "counts": {
    "lands": 3,
    "plants": 5,
    "seasons": 2,
    "harvests": 7,
    "animal_types": 4,
    "herds": 6
  },
  "totals": {
    "total_costs": 1500.5,
    "total_revenue": 3000.25,
    "profit": 1499.75
  },
  "recent": {
    "activities": [
      {
        "id": "1",
        "source_type": "plant",
        "source_id": "10",
        "type": "watering",
        "cost": 20.0,
        "date": "2026-09-01",
        "created_at": "2026-09-01T08:00:00Z",
        "updated_at": "2026-09-01T08:00:00Z"
      }
    ],
    "harvests": [
      {
        "id": "2",
        "season_id": "11",
        "quantity": 100.0,
        "unit": "kg",
        "date": "2026-09-02",
        "created_at": "2026-09-02T08:00:00Z",
        "updated_at": "2026-09-02T08:00:00Z"
      }
    ],
    "inputs": [
      {
        "id": "3",
        "source_type": "animal",
        "source_id": "12",
        "type": "feed",
        "cost": 40.0,
        "date": "2026-09-03",
        "created_at": "2026-09-03T08:00:00Z",
        "updated_at": "2026-09-03T08:00:00Z"
      }
    ],
    "revenues": [
      {
        "id": "4",
        "user_id": "1",
        "source": "plant",
        "source_id": "13",
        "type": "sale",
        "quantity": 5.0,
        "unit_price": 10.0,
        "total": 50.0,
        "date": "2026-09-04",
        "created_at": "2026-09-04T08:00:00Z",
        "updated_at": "2026-09-04T08:00:00Z"
      }
    ]
  }
}
''';

void main() {
  group('getDashboard', () {
    test('GETs /api/v1/dashboard and parses counts/totals/recent', () async {
      final adapter = _FakeAdapter(body: _fullBody);
      final source = DashboardRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getDashboard();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/dashboard');

      expect(result.counts.lands, 3);
      expect(result.counts.plants, 5);
      expect(result.counts.seasons, 2);
      expect(result.counts.harvests, 7);
      expect(result.counts.animalTypes, 4);
      expect(result.counts.herds, 6);

      expect(result.totals.totalCosts, 1500.5);
      expect(result.totals.totalRevenue, 3000.25);
      expect(result.totals.profit, 1499.75);

      expect(result.recent.activities, hasLength(1));
      expect(result.recent.activities.single.type, 'watering');
      expect(result.recent.harvests, hasLength(1));
      expect(result.recent.harvests.single.quantity, 100.0);
      expect(result.recent.inputs, hasLength(1));
      expect(result.recent.inputs.single.type, 'feed');
      expect(result.recent.revenues, hasLength(1));
      expect(result.recent.revenues.single.total, 50.0);
    });

    test('missing counts/totals/recent keys fall back to zeroed/empty data', () async {
      final adapter = _FakeAdapter(body: '{}');
      final source = DashboardRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getDashboard();

      expect(result.counts.lands, 0);
      expect(result.counts.herds, 0);
      expect(result.totals.totalCosts, 0);
      expect(result.totals.profit, 0);
      expect(result.recent.activities, isEmpty);
      expect(result.recent.harvests, isEmpty);
      expect(result.recent.inputs, isEmpty);
      expect(result.recent.revenues, isEmpty);
    });

    test(
      'a 401 throws UnauthorizedException via the generic DioException '
      'branch - mapDioException maps 401 -> UnauthorizedException '
      '(F1-05/S4-C1)',
      () async {
        final adapter = _FakeAdapter(body: '{}', statusCode: 401);
        final source = DashboardRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.getDashboard(),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = DashboardRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getDashboard(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-200/401/403 response throws ServerException with the server message', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = DashboardRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.getDashboard(),
        throwsA(
          isA<ServerException>().having((e) => e.message, 'message', 'boom'),
        ),
      );
    });
  });
}
