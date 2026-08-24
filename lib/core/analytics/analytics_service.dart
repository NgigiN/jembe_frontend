import 'dart:async';

import 'package:dio/dio.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';

/// Fire-and-forget usage analytics. Buffers [track] calls in memory and
/// flushes them as a batch on a timer or size threshold. A flush that
/// fails (network down, backend unreachable) drops the batch silently -
/// this is non-critical telemetry on a single-VPS backend that will
/// sometimes be down, and it must never block or crash a UI action.
class AnalyticsService {
  AnalyticsService({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;

  static const int maxBufferSize = 20;
  static const Duration flushInterval = Duration(seconds: 30);

  void track(String name, {Map<String, dynamic>? metadata}) {
    _buffer.add({
      'name': name,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'metadata': metadata ?? <String, dynamic>{},
    });
    _flushTimer ??= Timer(flushInterval, flush);
    if (_buffer.length >= maxBufferSize) {
      flush();
    }
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty) return;

    final events = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      await _dio.post('/api/v1/events', data: {'events': events});
    } catch (e) {
      appLogger.warning(
        LogCategory.general,
        'Analytics flush failed, dropping batch of ${events.length}',
        e,
      );
    }
  }
}
