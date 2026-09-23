import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farm_tracker/features/feed/data/datasources/feed_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a feed page response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _FakeAdapter();
    final ds = FeedRemoteDataSourceImpl(dio: dio);

    final page = await ds.getFeed();

    expect(page.entries, hasLength(1));
    expect(page.entries.first.entityType, 'activity');
    expect(page.nextBefore, '2026-09-22T09:00:00Z,41');
  });
}

class _FakeAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, contains('/farms/current/feed'));
    return ResponseBody.fromString(
      '{"entries":[{"entity_type":"activity","summary":"Activity: watering","logged_by":null,"created_at":"2026-09-22T10:00:00Z"}],"next_before":"2026-09-22T09:00:00Z,41"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
