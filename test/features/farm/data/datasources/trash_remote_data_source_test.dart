import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/trash_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [TrashRemoteDataSourceImpl] sends/expects for
/// `GET /api/v1/trash` (Phase 8 A2) and
/// `POST /api/v1/<path>/:id/restore` (A3).
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

const _groupedBody = '''
{
  "land": [
    {"id": 1, "name": "North Field", "deleted_at": "2026-09-01T08:00:00Z"}
  ],
  "plant": [],
  "season": [],
  "activity": [
    {"id": 5, "type": "watering", "date": "2026-08-20", "cost": 12.5}
  ],
  "input": [],
  "harvest": [
    {"id": 9, "quantity": 100, "unit": "kg", "date": "2026-08-15"}
  ],
  "animal_type": [],
  "herd": [],
  "animal": [],
  "infrastructure": [],
  "cost_category": [],
  "revenue": [
    {"id": 3}
  ]
}
''';

void main() {
  group('getTrash', () {
    test(
      'GETs /api/v1/trash and flattens the grouped response, tagging each '
      'item with its entity key and deriving a label',
      () async {
        final adapter = _FakeAdapter(body: _groupedBody);
        final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.getTrash();

        expect(adapter.lastOptions!.method, 'GET');
        expect(adapter.lastOptions!.path, '/api/v1/trash');

        expect(result, hasLength(4));

        final land = result.singleWhere((i) => i.entity == 'land');
        expect(land.id, '1');
        expect(land.label, 'North Field');
        expect(land.deletedAt, DateTime.parse('2026-09-01T08:00:00Z'));

        final activity = result.singleWhere((i) => i.entity == 'activity');
        expect(activity.id, '5');
        expect(activity.label, contains('watering'));

        final harvest = result.singleWhere((i) => i.entity == 'harvest');
        expect(harvest.id, '9');
        expect(harvest.label, contains('100'));
        expect(harvest.label, contains('kg'));

        final revenue = result.singleWhere((i) => i.entity == 'revenue');
        expect(revenue.id, '3');
        // No name/title/type/date/amount on this row: falls back to #<id>.
        expect(revenue.label, '#3');
      },
    );

    test('an empty trash response parses to an empty list', () async {
      final adapter = _FakeAdapter(
        body:
            '{"land":[],"plant":[],"season":[],"activity":[],"input":[],'
            '"harvest":[],"animal_type":[],"herd":[],"animal":[],'
            '"infrastructure":[],"cost_category":[],"revenue":[]}',
      );
      final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getTrash();

      expect(result, isEmpty);
    });

    test('a missing entity key is treated as no items for that entity', () async {
      final adapter = _FakeAdapter(body: '{"land": [{"id": 1, "name": "X"}]}');
      final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getTrash();

      expect(result, hasLength(1));
      expect(result.single.entity, 'land');
    });

    test(
      'a 401 throws UnauthorizedException via mapDioException '
      '(F1-05/S4-C1)',
      () async {
        final adapter = _FakeAdapter(body: '{}', statusCode: 401);
        final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.getTrash(),
          throwsA(isA<UnauthorizedException>()),
        );
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = TrashRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(source.getTrash(), throwsA(isA<NetworkException>()));
    });

    test(
      'a non-200/401 response throws ServerException with the server '
      'message',
      () async {
        final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
        final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.getTrash(),
          throwsA(
            isA<ServerException>().having((e) => e.message, 'message', 'boom'),
          ),
        );
      },
    );
  });

  group('restore', () {
    test(
      'POSTs to the pluralized/hyphenated path for each entity (not the '
      'bare snake_case trash-response key)',
      () async {
        final cases = {
          'land': '/api/v1/lands/1/restore',
          'plant': '/api/v1/plants/1/restore',
          'season': '/api/v1/seasons/1/restore',
          'activity': '/api/v1/activities/1/restore',
          'input': '/api/v1/inputs/1/restore',
          'harvest': '/api/v1/harvests/1/restore',
          'animal_type': '/api/v1/animal-types/1/restore',
          'herd': '/api/v1/herds/1/restore',
          'animal': '/api/v1/animals/1/restore',
          'infrastructure': '/api/v1/infrastructure/1/restore',
          'cost_category': '/api/v1/cost-categories/1/restore',
          'revenue': '/api/v1/revenue/1/restore',
        };

        for (final entry in cases.entries) {
          final adapter = _FakeAdapter(body: '{"id":1}');
          final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

          await source.restore(entity: entry.key, id: '1');

          expect(
            adapter.lastOptions!.path,
            entry.value,
            reason: 'entity=${entry.key}',
          );
          expect(adapter.lastOptions!.method, 'POST');
        }
      },
    );

    test(
      'a 409 throws ConflictException carrying the server message, '
      'distinct from a generic ServerException',
      () async {
        final adapter = _FakeAdapter(
          body: '{"error":"plant still deleted"}',
          statusCode: 409,
        );
        final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

        await expectLater(
          source.restore(entity: 'season', id: '1'),
          throwsA(
            isA<ConflictException>().having(
              (e) => e.message,
              'message',
              'plant still deleted',
            ),
          ),
        );
      },
    );

    test('a 404 throws a generic ServerException, not ConflictException', () async {
      final adapter = _FakeAdapter(body: '{"error":"not found"}', statusCode: 404);
      final source = TrashRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.restore(entity: 'land', id: '999'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'not found')
              .having((e) => e is ConflictException, 'is ConflictException', false),
        ),
      );
    });

    test('a connection failure throws NetworkException', () async {
      final source = TrashRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.restore(entity: 'land', id: '1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
