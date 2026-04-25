import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';

class GetProfile implements UseCase<User, NoParams> {
  GetProfile(this.repository);
  final ProfileRepository repository;

  @override
  Future<Either<Failure, User>> call(NoParams params) async {
    return repository.getProfile();
  }
}
