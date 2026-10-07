import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/auth/presentation/pages/google_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

Future<void> _pump(WidgetTester tester, AuthBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthBloc>.value(value: bloc, child: const GoogleLoginPage()),
    ),
  );
}

void main() {
  // A brand-new user is sent to onboarding to "set up your farm" — but the
  // backend already creates a default farm for them at sign-in, so the form
  // would make a SECOND one. The decision belongs on whether a farm exists,
  // not on the legacy per-user farmName/location fields it used to read.
  group('postSignInLocation', () {
    test('a user who already has a farm goes home', () {
      expect(postSignInLocation(hasFarm: true), AppRoutePath.home);
    });

    test('a user with no farm at all still gets onboarding', () {
      expect(postSignInLocation(hasFarm: false), AppRoutePath.onboarding);
    });
  });

  // Dismissing the Google sheet emitted AuthInitial and showed nothing, so the
  // screen simply reappeared with no explanation. Tapping again re-opened the
  // chooser: an infinite loop that produced no server traffic and no message.
  testWidgets('a cancelled sign-in explains itself', (tester) async {
    final bloc = MockAuthBloc();
    whenListen(
      bloc,
      Stream<AuthState>.fromIterable([
        AuthLoading(),
        AuthCancelled('Sign-in was not completed. Pick your account and allow access.'),
      ]),
      initialState: AuthInitial(),
    );

    await _pump(tester, bloc);
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('not completed'),
      findsOneWidget,
      reason: 'a dismissed sheet must say something rather than silently reset',
    );
  });

  // Every existing `state is AuthInitial` check (the splash and landing pages
  // both gate on it) must keep matching, or cancelling sign-in changes
  // navigation elsewhere as a side effect.
  test('AuthCancelled is still an AuthInitial', () {
    expect(AuthCancelled('x'), isA<AuthInitial>());
  });

  testWidgets('a real failure is still shown as an error', (tester) async {
    final bloc = MockAuthBloc();
    whenListen(
      bloc,
      Stream<AuthState>.fromIterable([AuthError('Google Sign-In failed (code).')]),
      initialState: AuthInitial(),
    );

    await _pump(tester, bloc);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Google Sign-In failed'), findsOneWidget);
  });
}
