import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

final _sensitiveLogPattern = RegExp(
  '(authorization|id_token|token|password|old_password|new_password)',
  caseSensitive: false,
);

void _redactedLogPrint(Object object) {
  final message = object.toString();
  if (_sensitiveLogPattern.hasMatch(message)) {
    debugPrint('[REDACTED HTTP LOG — contains sensitive auth data]');
    return;
  }
  debugPrint(message);
}

/// Factory for creating configured Dio instances
class DioClientFactory {
  static Dio create({
    required CacheStore cacheStore,
    required SessionExpiryNotifier sessionExpiry,
    String? baseUrl,
    bool enableLogging = true,
    bool enableCache = true,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add auth interceptor
    dio.interceptors.add(_AuthInterceptor());

    // Add retry interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired - could trigger refresh here
            //
            // NOTE: AnalyticsService (core/analytics/analytics_service.dart)
            // shares this Dio instance and posts to /api/v1/events on a
            // timer/size-triggered flush, including before login. Those
            // pre-login flushes are expected to 401 and are silently
            // dropped by AnalyticsService - a failed analytics flush must
            // never throw, retry, or surface an error to the user. The
            // public /auth/* endpoints (e.g. a bad Google token exchange)
            // are expected to 401 too. Both are carved out below so a
            // routine dropped-telemetry or failed-login 401 never turns
            // into user-visible auth churn; every other 401 forces logout.
            if (shouldForceLogoutOn401(error.requestOptions.path)) {
              sessionExpiry.expire();
            } else {
              appLogger.warning(
                LogCategory.auth,
                'Unauthorized request - token may be expired',
              );
            }
          }
          return handler.next(error);
        },
      ),
    );

    // Add cache interceptor (only in release mode for performance)
    if (enableCache && !kDebugMode) {
      dio.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: cacheStore,
            maxStale: const Duration(minutes: 5),
          ),
        ),
      );
    }

    // Add logging interceptor (only in debug mode; redact secrets)
    if (enableLogging && kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          logPrint: _redactedLogPrint,
        ),
      );
    }

    return dio;
  }
}

/// Interceptor that adds authentication token to requests
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await UserStorageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kReleaseMode) {
      appLogger.error(
        LogCategory.http,
        'Dio error: ${err.requestOptions.method} ${err.requestOptions.path}',
        err,
      );
    }
    handler.next(err);
  }
}

/// Maps a [DioException] to the appropriate application exception.
/// Connection / timeout errors become [NetworkException].
/// All other errors (4xx, 5xx) become [ServerException] with a human message.
Exceptions mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.connectionError:
      return NetworkException();
    default:
      final msg = extractServerErrorMessage(e.response?.data);
      return ServerException(msg.isNotEmpty ? msg : null);
  }
}

/// Extracts a human-readable error string from a JSON response body.
/// Returns empty string if none found.
String extractServerErrorMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    return (data['error'] ?? data['message'] ?? '').toString();
  }
  return '';
}
