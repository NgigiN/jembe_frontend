import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/domain/repositories/auth_repository.dart';

class GoogleSignInUseCase {
  GoogleSignInUseCase(this.repository);
  final AuthRepository repository;

  Future<Either<Failure, User>> call(String idToken) {
    return repository.googleSignIn(idToken);
  }
}
