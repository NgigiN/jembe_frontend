import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Signup implements UseCase<User, SignupParams> {
  final AuthRepository repository;

  Signup(this.repository);

  @override
  Future<Either<Failure, User>> call(SignupParams params) async {
    return await repository.signup(
      params.email,
      params.password,
      params.name,
      params.farmName,
      params.location,
    );
  }
}

class SignupParams {
  final String email;
  final String password;
  final String name;
  final String farmName;
  final String location;
  SignupParams({
    required this.email,
    required this.password,
    required this.name,
    required this.farmName,
    required this.location,
  });
}
