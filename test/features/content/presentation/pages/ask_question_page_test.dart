import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/features/content/domain/entities/question.dart';
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
      // A submit failure happens after questions have already been loaded,
      // so the loading/error states here carry forward an existing
      // question rather than an empty list - an empty-list QuestionError
      // is the distinct first-load-failure case (see the retry-view test
      // below), which now renders EntityErrorView instead of the form.
      final existingQuestion = Question(
        id: 'q0',
        questionText: 'An earlier question',
        status: 'unanswered',
        createdAt: DateTime(2026),
      );
      final bloc = MockQuestionBloc();
      whenListen(
        bloc,
        Stream<QuestionState>.fromIterable([
          // The initial GetQuestionsEvent settling first (as it would in
          // the real app) is what marks the page as having loaded once, so
          // the submit's own Loading/Error below are correctly treated as
          // "later" states rather than a first-load failure.
          QuestionLoaded(questions: [existingQuestion]),
          QuestionLoading(questions: [existingQuestion]),
          QuestionError(
            'Failed to submit question',
            questions: [existingQuestion],
          ),
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

  testWidgets(
    'a first-load error with no cached questions shows a retry view, '
    'not "No questions yet."',
    (tester) async {
      final bloc = MockQuestionBloc();
      whenListen(
        bloc,
        const Stream<QuestionState>.empty(),
        initialState: const QuestionError('Failed to load questions'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<QuestionBloc>.value(
            value: bloc,
            child: const AskQuestionPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Failed to load questions'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('No questions yet.'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      verify(() => bloc.add(any(that: isA<GetQuestionsEvent>())))
          .called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'an answer renders once answerText is set, regardless of status',
    (tester) async {
      final answeredQuestion = Question(
        id: 'q1',
        questionText: 'When should I vaccinate my calves?',
        status: 'unanswered',
        createdAt: DateTime(2026),
        answerText: 'Vaccinate calves between 2 and 4 months old.',
      );
      final bloc = MockQuestionBloc();
      whenListen(
        bloc,
        const Stream<QuestionState>.empty(),
        initialState: QuestionLoaded(questions: [answeredQuestion]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<QuestionBloc>.value(
            value: bloc,
            child: const AskQuestionPage(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Vaccinate calves between 2 and 4 months old.'),
        findsOneWidget,
      );
      expect(find.text('Awaiting a reply'), findsNothing);
    },
  );

  testWidgets(
    'a from-zero-questions submit failure keeps the form and typed text '
    'visible, and still tells the user something went wrong',
    (tester) async {
      // QuestionBloc threads the *current* questions list through the
      // Loading/Error it emits for a submit. For a user with no existing
      // questions, that list is empty - structurally identical to a
      // genuine first-load failure's empty list. The page must still tell
      // the two apart: this must fall through to the normal form (with the
      // typed draft intact), not the first-load EntityErrorView.
      final bloc = MockQuestionBloc();
      whenListen(
        bloc,
        Stream<QuestionState>.fromIterable([
          const QuestionLoaded(questions: []),
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
        'Why is my chicken not laying eggs?',
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();
      await tester.pump(); // let the error state land and the snackbar show

      // The form (and the typed draft) is still on screen - not replaced
      // by EntityErrorView, which offers no way back to the draft.
      expect(find.byType(EntityErrorView), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Why is my chicken not laying eggs?'),
        findsOneWidget,
      );

      // The user is still told the submission failed, via the snackbar.
      expect(find.text('Failed to submit question'), findsOneWidget);

      await sl<AnalyticsService>().flush();
    },
  );
}
