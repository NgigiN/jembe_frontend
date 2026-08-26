import 'dart:async';

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

  Widget pageUnder(QuestionBloc bloc) => MaterialApp(
    home: BlocProvider<QuestionBloc>.value(
      value: bloc,
      child: const AskQuestionPage(),
    ),
  );

  /// The form must survive every bloc state: the intro text, the input field
  /// and the Submit button are never replaced by a loading or error view.
  void expectFormIsIntact() {
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Your questions'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.text('Submit'),
      ),
      findsOneWidget,
    );
  }

  Finder snackBarText(String message) => find.descendant(
    of: find.byType(SnackBar),
    matching: find.text(message),
  );

  testWidgets('an empty or whitespace-only question is never submitted', (
    tester,
  ) async {
    final bloc = MockQuestionBloc();
    whenListen(
      bloc,
      const Stream<QuestionState>.empty(),
      initialState: QuestionInitial(),
    );

    await tester.pumpWidget(pageUnder(bloc));

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

  testWidgets('a rapid double-tap on Submit dispatches only one submission', (
    tester,
  ) async {
    final bloc = MockQuestionBloc();
    whenListen(
      bloc,
      const Stream<QuestionState>.empty(),
      initialState: const QuestionLoaded(questions: []),
    );

    await tester.pumpWidget(pageUnder(bloc));

    await tester.enterText(find.byType(TextField), 'Is my soil too acidic?');
    // Both taps land before the frame that rebuilds the button in its
    // disabled state, so the in-flight guard inside _submit() - not just the
    // disabled button - is what has to swallow the second one.
    await tester.tap(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<SubmitQuestionEvent>()))).called(1);

    await sl<AnalyticsService>().flush();
  });

  testWidgets(
    'a failed submit does not clear the typed question from the field',
    (tester) async {
      // A submit failure that happens with questions already loaded: the bloc
      // threads that list through its Loading and Error, so the questions
      // section keeps showing it and the user is told what happened via a
      // snackbar.
      final existingQuestion = Question(
        id: 'q0',
        questionText: 'An earlier question',
        status: 'unanswered',
        createdAt: DateTime(2026),
      );
      // States are pushed one at a time rather than from a pre-built
      // iterable, so that the submit really is dispatched *before* its
      // failure arrives. A `Stream.fromIterable` drains entirely during
      // pumpWidget, which would leave the tap happening after the error had
      // already been handled.
      final controller = StreamController<QuestionState>.broadcast();
      addTearDown(controller.close);
      final bloc = MockQuestionBloc();
      whenListen(bloc, controller.stream, initialState: QuestionInitial());

      await tester.pumpWidget(pageUnder(bloc));
      controller.add(QuestionLoaded(questions: [existingQuestion]));
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'How often should I deworm my goats?',
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();

      controller.add(QuestionLoading(questions: [existingQuestion]));
      await tester.pump();
      controller.add(
        QuestionError(
          'Failed to submit question',
          questions: [existingQuestion],
        ),
      );
      await tester.pump();
      await tester.pump(); // let the snackbar show

      expect(find.text('How often should I deworm my goats?'), findsOneWidget);
      expectFormIsIntact();
      // The already-loaded question is still listed, not replaced by an error
      // view.
      expect(find.text('An earlier question'), findsOneWidget);
      expect(find.byType(EntityErrorView), findsNothing);
      expect(snackBarText('Failed to submit question'), findsOneWidget);

      // _submit() calls AnalyticsService.track() before dispatching, which
      // schedules a real 30s flush Timer. flutter_test's
      // AutomatedTestWidgetsFlutterBinding asserts no Timer is left pending
      // when a test ends, so drain it explicitly here rather than waiting.
      await sl<AnalyticsService>().flush();
    },
  );

  testWidgets(
    'a first-load error with no cached questions shows a retry view in the '
    'questions section, with the form still intact above it',
    (tester) async {
      // Deliver the states through a real Stream (not a pre-seeded
      // `initialState:`), mirroring exactly how this happens in the real app:
      // initState dispatches GetQuestionsEvent, the bloc emits
      // QuestionLoading, then QuestionError once it fails. Seeding the error
      // directly via `initialState:` would bypass the BlocConsumer's listener
      // entirely for that first state, which previously let a regression here
      // go undetected.
      final bloc = MockQuestionBloc();
      whenListen(
        bloc,
        Stream<QuestionState>.fromIterable([
          const QuestionLoading(),
          const QuestionError('Failed to load questions'),
        ]),
        initialState: QuestionInitial(),
      );

      await tester.pumpWidget(pageUnder(bloc));
      await tester.pump();
      await tester.pump(); // let QuestionLoading, then QuestionError land

      expect(find.byType(EntityErrorView), findsOneWidget);
      expect(find.text('Failed to load questions'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('No questions yet.'), findsNothing);
      // The error is scoped to the questions section: the form above it is
      // untouched and still usable.
      expectFormIsIntact();

      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      verify(
        () => bloc.add(any(that: isA<GetQuestionsEvent>())),
      ).called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets('an answer renders once answerText is set, regardless of status', (
    tester,
  ) async {
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

    await tester.pumpWidget(pageUnder(bloc));
    await tester.pump();

    expect(
      find.text('Vaccinate calves between 2 and 4 months old.'),
      findsOneWidget,
    );
    expect(find.text('Awaiting a reply'), findsNothing);
  });

  testWidgets(
    'a from-zero-questions submit failure keeps the form and typed text '
    'visible, and still tells the user something went wrong',
    (tester) async {
      // QuestionBloc threads the *current* questions list through the
      // Loading/Error it emits for a submit. For a user with no existing
      // questions that list is empty - structurally identical to a genuine
      // first-load failure's empty list. The page no longer has to tell the
      // two apart: the form renders unconditionally either way, so the typed
      // draft survives, and the questions section (which has nothing of its
      // own to lose) is free to show the error inline.
      final controller = StreamController<QuestionState>.broadcast();
      addTearDown(controller.close);
      final bloc = MockQuestionBloc();
      whenListen(bloc, controller.stream, initialState: QuestionInitial());

      await tester.pumpWidget(pageUnder(bloc));
      controller.add(const QuestionLoaded(questions: []));
      await tester.pump();
      expect(find.text('No questions yet.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Why is my chicken not laying eggs?',
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();

      controller.add(const QuestionLoading());
      await tester.pump();
      controller.add(const QuestionError('Failed to submit question'));
      await tester.pump();
      await tester.pump(); // let the snackbar show

      // The form, and the typed draft, are still on screen.
      expectFormIsIntact();
      expect(find.text('Why is my chicken not laying eggs?'), findsOneWidget);

      // A failed submit is always reported by snackbar - the questions
      // section can be scrolled out of view behind the keyboard, so it is not
      // on its own reliable feedback for an action the user just took.
      expect(snackBarText('Failed to submit question'), findsOneWidget);

      await sl<AnalyticsService>().flush();
    },
  );

  testWidgets(
    'a later unrelated error never hides questions loaded by a retry',
    (tester) async {
      // The regression this guards: a first-load failure must not leave any
      // latched "show the error view" decision behind. Once a retry succeeds,
      // a later failure that carries the loaded questions has to keep showing
      // them.
      final question = Question(
        id: 'q2',
        questionText: 'When do I plant maize?',
        status: 'unanswered',
        createdAt: DateTime(2026),
      );
      final controller = StreamController<QuestionState>.broadcast();
      addTearDown(controller.close);
      final bloc = MockQuestionBloc();
      whenListen(bloc, controller.stream, initialState: QuestionInitial());

      await tester.pumpWidget(pageUnder(bloc));

      // 1. The first-ever load fails.
      controller.add(const QuestionLoading());
      await tester.pump();
      controller.add(const QuestionError('Failed to load questions'));
      await tester.pump();
      expect(find.byType(EntityErrorView), findsOneWidget);
      expectFormIsIntact();

      // 2. The user retries from the questions section, and it succeeds.
      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      verify(
        () => bloc.add(any(that: isA<GetQuestionsEvent>())),
      ).called(greaterThanOrEqualTo(1));

      controller.add(const QuestionLoading());
      await tester.pump();
      controller.add(QuestionLoaded(questions: [question]));
      await tester.pump();
      expect(find.text('When do I plant maize?'), findsOneWidget);
      expect(find.byType(EntityErrorView), findsNothing);

      // 3. A later, unrelated failure arrives carrying that same list.
      controller.add(
        QuestionError('Failed to submit question', questions: [question]),
      );
      await tester.pump();
      await tester.pump(); // let the snackbar show

      expect(find.text('When do I plant maize?'), findsOneWidget);
      expect(find.byType(EntityErrorView), findsNothing);
      expect(find.text('No questions yet.'), findsNothing);
      expectFormIsIntact();
      expect(snackBarText('Failed to submit question'), findsOneWidget);
    },
  );
}
