import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_sign_in_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  setUpAll(() => registerFallbackValue(GoogleSignInRequested()));

  testWidgets('tapping sign in dispatches the sign-in event', (tester) async {
    final authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(), initialState: AuthInitial());

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const MaterialApp(home: WebSignInPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    verify(() => authBloc.add(any(that: isA<GoogleSignInRequested>()))).called(1);
  });
}
