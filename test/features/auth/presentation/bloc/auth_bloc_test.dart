import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/domain/usecases/login.dart';
import 'package:farm_tracker/features/auth/domain/usecases/signup.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';

class MockLogin extends Mock implements Login {}

class MockSignup extends Mock implements Signup {}

void main() {
  late AuthBloc authBloc;
  late MockLogin mockLogin;
  late MockSignup mockSignup;

  setUp(() {
    mockLogin = MockLogin();
    mockSignup = MockSignup();
    authBloc = AuthBloc(login: mockLogin, signup: mockSignup);
  });

  tearDown(() {
    authBloc.close();
  });

  final tUser = User(
    id: '1',
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
    farmName: 'Test Farm',
    location: 'Test Location',
  );

  group('LoginEvent', () {
    test('initial state should be AuthInitial', () {
      expect(authBloc.state, equals(AuthInitial()));
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when login succeeds',
      build: () {
        when(() => mockLogin(any())).thenAnswer(
          (_) async => Right(tUser),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(
        LoginEvent(email: 'test@example.com', password: 'password'),
      ),
      expect: () => [
        AuthLoading(),
        AuthAuthenticated(tUser),
      ],
      verify: (_) {
        verify(() => mockLogin(any())).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when login fails',
      build: () {
        when(() => mockLogin(any())).thenAnswer(
          (_) async => Left(ServerFailure('Login failed')),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(
        LoginEvent(email: 'test@example.com', password: 'wrong'),
      ),
      expect: () => [
        AuthLoading(),
        AuthError('Login failed'),
      ],
    );
  });

  group('SignupEvent', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, SignupSuccess] when signup succeeds',
      build: () {
        when(() => mockSignup(any())).thenAnswer(
          (_) async => Right(tUser),
        );
        return authBloc;
      },
      act: (bloc) => bloc.add(
        SignupEvent(
          email: 'test@example.com',
          password: 'password',
          firstName: 'Test',
          lastName: 'User',
          farmName: 'Test Farm',
          location: 'Test Location',
        ),
      ),
      expect: () => [
        AuthLoading(),
        SignupSuccess(),
      ],
    );
  });
}

