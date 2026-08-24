import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('AnalyticsService', () {
    late MockDio dio;
    late AnalyticsService service;

    setUp(() {
      dio = MockDio();
      service = AnalyticsService(dio: dio);
    });

    test('flush posts buffered events and clears the buffer', () async {
      when(
        () => dio.post(any(), data: any(named: 'data')),
      ).thenAnswer((_) async => Response(requestOptions: RequestOptions(), statusCode: 201));

      service.track('app_open');
      await service.flush();

      final captured = verify(
        () => dio.post('/api/v1/events', data: captureAny(named: 'data')),
      ).captured;
      final body = captured.single as Map<String, dynamic>;
      final events = body['events'] as List;
      expect(events, hasLength(1));
      expect(events.single['name'], 'app_open');

      // A second flush with nothing buffered must not POST again.
      await service.flush();
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });

    test('a failed flush drops the buffer without throwing or retrying', () async {
      when(
        () => dio.post(any(), data: any(named: 'data')),
      ).thenThrow(DioException(requestOptions: RequestOptions()));

      service.track('content_view', metadata: {'content_id': 'x'});

      await expectLater(service.flush(), completes);

      // Buffer was cleared before the failed POST, so a second flush
      // has nothing to send - proves the batch was dropped, not retried.
      await service.flush();
      verify(() => dio.post(any(), data: any(named: 'data'))).called(1);
    });
  });
}
