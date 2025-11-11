import 'package:http/http.dart' as http;
import '../logging/app_logger.dart';

class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;
  final AppLogger _logger;

  LoggingHttpClient(this._inner) : _logger = appLogger;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();

    _logger.logHttpRequest(
      request.method,
      request.url.toString(),
      headers: request.headers,
      body: request is http.Request ? request.body : null,
    );

    try {
      final response = await _inner.send(request);
      stopwatch.stop();

      // Read response body for logging
      final responseBody = await response.stream.bytesToString();

      _logger.logHttpResponse(
        request.method,
        request.url.toString(),
        response.statusCode,
        body: responseBody,
        duration: stopwatch.elapsed,
      );

      // Return response with the body stream reset
      return http.StreamedResponse(
        Stream.value(responseBody.codeUnits),
        response.statusCode,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.error(
        LogCategory.http,
        'HTTP Request failed: ${request.method} ${request.url}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
