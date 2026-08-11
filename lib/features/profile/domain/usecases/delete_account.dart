import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';

class DeleteAccount implements UseCase<void, NoParams> {
  DeleteAccount(this.repository);
  final ProfileRepository repository;

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return repository.deleteAccount();
  }
}
