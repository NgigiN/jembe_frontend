// test/features/web_console/presentation/pages/web_sign_in_page_test.dart
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_sign_in_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  setUpAll(
    () => registerFallbackValue(GoogleSignInWebAccountReceived('fallback-token')),
  );

  late MockAuthBloc authBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthInitial(),
    );
  });

  Widget harness(Widget page) => BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp(home: page),
  );

  testWidgets('shows a loading indicator until ensureInitialized resolves', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      harness(
        WebSignInPage(
          ensureInitialized: () => completer.future,
          idTokenEvents: const Stream<String>.empty(),
        ),
      ),
    );
    await tester.pump();

    // The console shows a placeholder shaped like the button rather than a
    // spinner (DESIGN_SPEC §6).
    expect(find.text('Preparing sign-in\u2026'), findsOneWidget);
    expect(find.byType(GoogleSignInButton), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('Preparing sign-in\u2026'), findsNothing);
    expect(find.byType(GoogleSignInButton), findsOneWidget);
  });

  testWidgets('shows an error message when ensureInitialized fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        WebSignInPage(
          ensureInitialized: () => Future<void>.error(Exception('boom')),
          idTokenEvents: const Stream<String>.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sign-in is unavailable just now. Refresh the page and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(GoogleSignInButton), findsNothing);
  });

  testWidgets(
    'dispatches GoogleSignInWebAccountReceived when the token stream emits',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        harness(
          WebSignInPage(
            ensureInitialized: () async {},
            idTokenEvents: controller.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.add('real-id-token');
      await tester.pump();

      verify(
        () => authBloc.add(
          any(
            that: isA<GoogleSignInWebAccountReceived>().having(
              (e) => e.idToken,
              'idToken',
              'real-id-token',
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('shows a SnackBar when AuthBloc emits AuthError', (tester) async {
    final controller = StreamController<AuthState>();
    addTearDown(controller.close);
    whenListen(authBloc, controller.stream, initialState: AuthInitial());

    await tester.pumpWidget(
      harness(
        WebSignInPage(
          ensureInitialized: () async {},
          idTokenEvents: const Stream<String>.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.add(AuthError('Sign-in failed on the backend'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sign-in failed on the backend'), findsOneWidget);
  });
}
