import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../../features/auth/data/services/user_storage_service.dart';

/// Factory for creating configured Dio instances
class DioClientFactory {
  static Dio create({
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
            appLogger.warning(
              LogCategory.auth,
              'Unauthorized request - token may be expired',
            );
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
            store: MemCacheStore(),
            policy: CachePolicy.request,
            maxStale: const Duration(minutes: 5),
          ),
        ),
      );
    }

    // Add logging interceptor (only in debug mode)
    if (enableLogging && kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
    }

    return dio;
  }
}

/// Interceptor that adds authentication token to requests
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
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

