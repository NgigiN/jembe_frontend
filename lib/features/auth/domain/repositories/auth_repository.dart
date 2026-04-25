import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> googleSignIn(String idToken);
}
