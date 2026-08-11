import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

enum LogLevel { debug, info, warning, error }

enum LogCategory { navigation, http, auth, farm, general }

class AppLogger {
  factory AppLogger() => _instance;
  AppLogger._internal();
  static final AppLogger _instance = AppLogger._internal();

  late final Logger _logger;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    _logger = Logger(
      printer: PrettyPrinter(
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: kDebugMode ? Level.debug : Level.warning,
    );
    _isInitialized = true;
  }

  void _log(
    Level level,
    LogCategory category,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (!_isInitialized) initialize();

    final shouldEmit = !kReleaseMode || level.index >= Level.warning.index;
    if (!shouldEmit) return;

    final categoryPrefix = '[${category.name.toUpperCase()}]';
    final formattedMessage = '$categoryPrefix $message';

    _logger.log(level, formattedMessage, error: error, stackTrace: stackTrace);
  }

  void debug(
    LogCategory category,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(Level.debug, category, message, error, stackTrace);
  }

  void info(
    LogCategory category,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(Level.info, category, message, error, stackTrace);
  }

  void warning(
    LogCategory category,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(Level.warning, category, message, error, stackTrace);
  }

  void error(
    LogCategory category,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _log(Level.error, category, message, error, stackTrace);
  }

  void logNavigation(String from, String to, {Map<String, dynamic>? params}) {
    final paramsStr = params != null ? ' with params: $params' : '';
    info(LogCategory.navigation, 'Navigating from "$from" to "$to"$paramsStr');
  }

  void logHttpRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) {
    final headersStr = headers != null
        ? ' | Headers: ${headers.keys.join(', ')}'
        : '';
    final bodyStr = body != null
        ? ' | Body: ${body.toString().length > 200 ? '${body.toString().substring(0, 200)}...' : body}'
        : '';
    debug(LogCategory.http, '$method $url$headersStr$bodyStr');
  }

  void logHttpResponse(
    String method,
    String url,
    int statusCode, {
    dynamic body,
    Duration? duration,
  }) {
    final durationStr = duration != null
        ? ' | Duration: ${duration.inMilliseconds}ms'
        : '';
    final bodyStr = body != null
        ? ' | Body: ${body.toString().length > 200 ? '${body.toString().substring(0, 200)}...' : body}'
        : '';

    if (statusCode >= 200 && statusCode < 300) {
      info(LogCategory.http, '$method $url -> $statusCode$durationStr$bodyStr');
    } else if (statusCode >= 400) {
      error(
        LogCategory.http,
        '$method $url -> $statusCode$durationStr$bodyStr',
      );
    } else {
      warning(
        LogCategory.http,
        '$method $url -> $statusCode$durationStr$bodyStr',
      );
    }
  }

  void logAuthEvent(
    String event, {
    String? userId,
    Map<String, dynamic>? details,
  }) {
    final userStr = userId != null ? ' | User: $userId' : '';
    final detailsStr = details != null ? ' | Details: $details' : '';
    info(LogCategory.auth, 'Auth Event: $event$userStr$detailsStr');
  }

  void logFarmOperation(
    String operation, {
    String? entityId,
    Map<String, dynamic>? data,
  }) {
    final entityStr = entityId != null ? ' | Entity: $entityId' : '';
    final dataStr = data != null ? ' | Data: $data' : '';
    info(LogCategory.farm, 'Farm Operation: $operation$entityStr$dataStr');
  }

  void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    _log(
      Level.error,
      LogCategory.general,
      'Error in $context: $error',
      error,
      stackTrace,
    );
  }
}

final appLogger = AppLogger();
