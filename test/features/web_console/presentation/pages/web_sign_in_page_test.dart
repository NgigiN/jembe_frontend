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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GoogleSignInButton), findsNothing);

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
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
      find.text('Sign-in is currently unavailable. Please try again shortly.'),
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
}
