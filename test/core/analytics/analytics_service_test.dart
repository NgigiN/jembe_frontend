import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
      when(() => dio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
        (_) async =>
            Response(requestOptions: RequestOptions(), statusCode: 201),
      );

      service.track('app_open');
      await service.flush();

      final captured = verify(
        () => dio.post<void>('/api/v1/events', data: captureAny(named: 'data')),
      ).captured;
      final body = captured.single as Map<String, dynamic>;
      final events = body['events'] as List;
      expect(events, hasLength(1));
      expect(events.single['name'], 'app_open');

      // A second flush with nothing buffered must not POST again.
      await service.flush();
      verifyNever(() => dio.post<void>(any(), data: any(named: 'data')));
    });

    test(
      'a failed flush drops the buffer without throwing or retrying',
      () async {
        when(
          () => dio.post<void>(any(), data: any(named: 'data')),
        ).thenThrow(DioException(requestOptions: RequestOptions()));

        service.track('content_view', metadata: {'content_id': 'x'});

        await expectLater(service.flush(), completes);

        // Buffer was cleared before the failed POST, so a second flush
        // has nothing to send - proves the batch was dropped, not retried.
        await service.flush();
        verify(() => dio.post<void>(any(), data: any(named: 'data'))).called(1);
      },
    );

    test(
      'track() called maxBufferSize times triggers an automatic flush',
      () async {
        when(() => dio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
          (_) async =>
              Response(requestOptions: RequestOptions(), statusCode: 201),
        );

        for (var i = 0; i < AnalyticsService.maxBufferSize; i++) {
          service.track('event_$i');
        }

        // track() triggers the flush without awaiting it - wait for the
        // mocked POST to actually be called rather than assuming timing.
        await untilCalled(
          () => dio.post<void>(any(), data: any(named: 'data')),
        );

        final captured = verify(
          () =>
              dio.post<void>('/api/v1/events', data: captureAny(named: 'data')),
        ).captured;
        final body = captured.single as Map<String, dynamic>;
        final events = body['events'] as List;
        expect(events, hasLength(AnalyticsService.maxBufferSize));
      },
    );

    test(
      'the flush timer automatically flushes once flushInterval elapses',
      () {
        when(() => dio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
          (_) async =>
              Response(requestOptions: RequestOptions(), statusCode: 201),
        );

        fakeAsync((async) {
          service.track('app_open');

          // Just short of the interval, nothing should have been sent yet.
          async.elapse(
            AnalyticsService.flushInterval - const Duration(seconds: 1),
          );
          verifyNever(() => dio.post<void>(any(), data: any(named: 'data')));

          // Crossing the threshold fires the timer's flush.
          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();

          final captured = verify(
            () => dio.post<void>(
              '/api/v1/events',
              data: captureAny(named: 'data'),
            ),
          ).captured;
          final body = captured.single as Map<String, dynamic>;
          final events = body['events'] as List;
          expect(events, hasLength(1));
        });
      },
    );
  });
}
