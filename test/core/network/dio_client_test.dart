import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCacheStore extends Mock implements CacheStore {}

/// Returns a canned status code for every request, no matter the path -
/// enough to drive Dio's real interceptor chain through `DioClientFactory`
/// without a live server.
class _FixedStatusAdapter implements HttpClientAdapter {
  _FixedStatusAdapter(this.statusCode);
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mapDioException', () {
    test('a 401 response maps to UnauthorizedException (F1-05/S4-C1)', () {
      final requestOptions = RequestOptions(path: '/api/v1/lands');
      final e = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 401,
        ),
      );

      expect(mapDioException(e), isA<UnauthorizedException>());
    });

    test('a 403 response still maps to ServerException (unchanged)', () {
      final requestOptions = RequestOptions(path: '/api/v1/lands');
      final e = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 403,
          data: {'error': 'forbidden'},
        ),
      );

      final result = mapDioException(e);
      expect(result, isA<ServerException>());
      expect((result as ServerException).message, 'forbidden');
    });

    test('a 500 response still maps to ServerException(msg) (unchanged)', () {
      final requestOptions = RequestOptions(path: '/api/v1/lands');
      final e = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
          data: {'error': 'boom'},
        ),
      );

      final result = mapDioException(e);
      expect(result, isA<ServerException>());
      expect((result as ServerException).message, 'boom');
    });

    test('a connection error still maps to NetworkException (unchanged)', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/api/v1/lands'),
        type: DioExceptionType.connectionError,
      );

      expect(mapDioException(e), isA<NetworkException>());
    });
  });

  group('DioClientFactory 401 interceptor (choke point for force-logout)', () {
    // The interceptor's onRequest reads the stored token via
    // UserStorageService.getToken(), which falls back to shared_preferences
    // when secure storage is unavailable - both need a mocked backing store
    // to resolve in a VM test (mirrors auth_bloc_logout_test.dart's setup).
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null);
    });

    test(
      'a 401 on a protected path calls sessionExpiry.expire() - the hook '
      'main.dart listens on to dispatch LogoutEvent',
      () async {
        final sessionExpiry = SessionExpiryNotifier();
        var expired = false;
        sessionExpiry.addListener(() => expired = true);

        final dio = DioClientFactory.create(
          cacheStore: _MockCacheStore(),
          sessionExpiry: sessionExpiry,
          baseUrl: 'https://example.test',
          enableLogging: false,
        )..httpClientAdapter = _FixedStatusAdapter(401);

        await expectLater(
          dio.get<dynamic>('/api/v1/lands'),
          throwsA(isA<DioException>()),
        );

        expect(expired, isTrue);
      },
    );

    test(
      'a 401 on /api/v1/auth/google does NOT call sessionExpiry.expire() - '
      'carved out so a bad login attempt cannot force-logout/loop',
      () async {
        final sessionExpiry = SessionExpiryNotifier();
        var expired = false;
        sessionExpiry.addListener(() => expired = true);

        final dio = DioClientFactory.create(
          cacheStore: _MockCacheStore(),
          sessionExpiry: sessionExpiry,
          baseUrl: 'https://example.test',
          enableLogging: false,
        )..httpClientAdapter = _FixedStatusAdapter(401);

        await expectLater(
          dio.post<dynamic>('/api/v1/auth/google'),
          throwsA(isA<DioException>()),
        );

        expect(expired, isFalse);
      },
    );

    test(
      'a 401 on /api/v1/events (analytics) does NOT call '
      'sessionExpiry.expire() - pre-login telemetry flushes are expected '
      'to 401',
      () async {
        final sessionExpiry = SessionExpiryNotifier();
        var expired = false;
        sessionExpiry.addListener(() => expired = true);

        final dio = DioClientFactory.create(
          cacheStore: _MockCacheStore(),
          sessionExpiry: sessionExpiry,
          baseUrl: 'https://example.test',
          enableLogging: false,
        )..httpClientAdapter = _FixedStatusAdapter(401);

        await expectLater(
          dio.post<dynamic>('/api/v1/events'),
          throwsA(isA<DioException>()),
        );

        expect(expired, isFalse);
      },
    );

    test('a 200 response never calls sessionExpiry.expire()', () async {
      final sessionExpiry = SessionExpiryNotifier();
      var expired = false;
      sessionExpiry.addListener(() => expired = true);

      final dio = DioClientFactory.create(
        cacheStore: _MockCacheStore(),
        sessionExpiry: sessionExpiry,
        baseUrl: 'https://example.test',
        enableLogging: false,
      )..httpClientAdapter = _FixedStatusAdapter(200);

      await dio.get<dynamic>('/api/v1/lands');

      expect(expired, isFalse);
    });
  });
}
