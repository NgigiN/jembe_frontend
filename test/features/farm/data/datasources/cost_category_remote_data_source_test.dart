import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the wire contract [CostCategoryRemoteDataSourceImpl] sends/expects
/// today — the R2-01 prerequisite. Unlike every other farm entity, `add`
/// here takes bare named params (no model) and the server returns a bare
/// `bool`, not the created row — see `CostCategoryModel`'s class docs.
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
  group('getCostCategories', () {
    test('GETs /api/v1/cost-categories and parses each row', () async {
      final adapter = _FakeAdapter(
        body:
            '[{"id":"1","name":"Seeds","type":"plant","category":"input",'
            '"is_default":true}]',
      );
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getCostCategories();

      expect(adapter.lastOptions!.method, 'GET');
      expect(adapter.lastOptions!.path, '/api/v1/cost-categories');
      expect(result.single.name, 'Seeds');
      expect(result.single.isDefault, isTrue);
    });

    test('sends type/category as query params only when given', () async {
      final adapter = _FakeAdapter(body: '[]');
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.getCostCategories(type: 'plant', category: 'input');

      expect(adapter.lastOptions!.uri.queryParameters['type'], 'plant');
      expect(adapter.lastOptions!.uri.queryParameters['category'], 'input');
    });

    test('an is_default missing from the response defaults to false', () async {
      final adapter = _FakeAdapter(
        body: '[{"id":"2","name":"Custom","type":"plant","category":"input"}]',
      );
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      final result = await source.getCostCategories();

      expect(result.single.isDefault, isFalse);
    });

    test('a connection failure throws NetworkException', () async {
      final source = CostCategoryRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.getCostCategories(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-200 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 500);
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.getCostCategories(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('addCostCategory', () {
    test(
      'POSTs to /api/v1/cost-categories with name/type/category and '
      'returns true on 201, OMITTING client_uuid when none is given',
      () async {
        final adapter = _FakeAdapter(body: '{}', statusCode: 201);
        final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

        final result = await source.addCostCategory(
          name: 'Seeds',
          type: 'plant',
          category: 'input',
        );

        expect(adapter.lastOptions!.method, 'POST');
        expect(adapter.lastOptions!.path, '/api/v1/cost-categories');
        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body, {'name': 'Seeds', 'type': 'plant', 'category': 'input'});
        expect(result, isTrue);
      },
    );

    test(
      'a given clientUuid (offline sync path) IS spread into the body',
      () async {
        final adapter = _FakeAdapter(body: '{}', statusCode: 201);
        final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

        await source.addCostCategory(
          name: 'Seeds',
          type: 'plant',
          category: 'input',
          clientUuid: 'cu-1',
        );

        final body = adapter.lastOptions!.data as Map<String, dynamic>;
        expect(body['client_uuid'], 'cu-1');
      },
    );

    test('a connection failure throws NetworkException', () async {
      final source = CostCategoryRemoteDataSourceImpl(
        dio: _dioWith(_ThrowingAdapter()),
      );

      await expectLater(
        source.addCostCategory(name: 'Seeds', type: 'plant', category: 'input'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a non-2xx response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"boom"}', statusCode: 422);
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.addCostCategory(name: 'Seeds', type: 'plant', category: 'input'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('deleteCostCategory', () {
    test('DELETEs /api/v1/cost-categories/:id', () async {
      final adapter = _FakeAdapter(body: 'null');
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      await source.deleteCostCategory('9');

      expect(adapter.lastOptions!.method, 'DELETE');
      expect(adapter.lastOptions!.path, '/api/v1/cost-categories/9');
    });

    test('a non-200/204 response throws ServerException', () async {
      final adapter = _FakeAdapter(body: '{"error":"nope"}', statusCode: 500);
      final source = CostCategoryRemoteDataSourceImpl(dio: _dioWith(adapter));

      await expectLater(
        source.deleteCostCategory('9'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
