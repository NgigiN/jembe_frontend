import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_state.dart';
import 'package:farm_tracker/features/content/presentation/pages/ask_question_page.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockQuestionBloc extends MockBloc<QuestionEvent, QuestionState>
    implements QuestionBloc {}

class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(GetQuestionsEvent());
  });

  // A successful submit is never reached in these tests, but AskQuestionPage
  // reads AnalyticsService from the service locator before dispatching the
  // submit event, so it must be registered for the page to build at all.
  setUp(() {
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(dio: MockDio()),
    );
  });

  tearDown(() {
    sl.unregister<AnalyticsService>();
  });

  testWidgets('an empty or whitespace-only question is never submitted', (
    tester,
  ) async {
    final bloc = MockQuestionBloc();
    whenListen(
      bloc,
      const Stream<QuestionState>.empty(),
      initialState: QuestionInitial(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<QuestionBloc>.value(
          value: bloc,
          child: const AskQuestionPage(),
        ),
      ),
    );

    // Never typed anything. (initState already dispatched GetQuestionsEvent,
    // so we only assert that no SubmitQuestionEvent was ever added.)
    await tester.tap(find.text('Submit'));
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<SubmitQuestionEvent>())));

    // Whitespace only.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    verifyNever(() => bloc.add(any(that: isA<SubmitQuestionEvent>())));
  });

  testWidgets(
    'a failed submit does not clear the typed question from the field',
    (tester) async {
      final bloc = MockQuestionBloc();
      whenListen(
        bloc,
        Stream<QuestionState>.fromIterable([
          const QuestionLoading(),
          const QuestionError('Failed to submit question'),
        ]),
        initialState: QuestionInitial(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<QuestionBloc>.value(
            value: bloc,
            child: const AskQuestionPage(),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'How often should I deworm my goats?',
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();
      await tester.pump(); // let the error state land and the snackbar show

      expect(
        find.text('How often should I deworm my goats?'),
        findsOneWidget,
      );

      // _submit() calls AnalyticsService.track() before dispatching, which
      // schedules a real 30s flush Timer. flutter_test's
      // AutomatedTestWidgetsFlutterBinding asserts no Timer is left pending
      // when a test ends, so drain it explicitly here rather than waiting.
      await sl<AnalyticsService>().flush();
    },
  );
}
