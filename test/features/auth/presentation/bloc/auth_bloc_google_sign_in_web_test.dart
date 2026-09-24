import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/domain/usecases/google_sign_in_usecase.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoogleSignInUseCase extends Mock implements GoogleSignInUseCase {}

void main() {
  late _MockGoogleSignInUseCase useCase;

  setUp(() => useCase = _MockGoogleSignInUseCase());

  test(
    'GoogleSignInWebAccountReceived emits AuthLoading then AuthAuthenticated on success',
    () async {
      const user = User(
        id: '1',
        email: 'amina@example.com',
        firstName: 'Amina',
        lastName: 'Kamau',
        farmName: 'Kamau Farm',
        location: 'Nakuru',
        pictureUrl: '',
      );
      when(() => useCase('token-123')).thenAnswer((_) async => const Right(user));

      final bloc = AuthBloc(googleSignInUseCase: useCase);
      addTearDown(bloc.close);

      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(GoogleSignInWebAccountReceived('token-123'));
      await bloc.stream.firstWhere((s) => s is AuthAuthenticated);

      expect(states, [isA<AuthLoading>(), isA<AuthAuthenticated>()]);
    },
  );

  test('GoogleSignInWebAccountReceived emits AuthError on failure', () async {
    when(
      () => useCase('bad-token'),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final bloc = AuthBloc(googleSignInUseCase: useCase);
    addTearDown(bloc.close);

    bloc.add(GoogleSignInWebAccountReceived('bad-token'));
    final state = await bloc.stream.firstWhere((s) => s is AuthError);

    expect(state, isA<AuthError>());
  });
}
