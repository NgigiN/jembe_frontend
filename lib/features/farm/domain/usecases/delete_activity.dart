import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';

class DeleteActivity implements UseCase<void, DeleteActivityParams> {
  DeleteActivity(this.repository);
  final ActivityRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteActivityParams params) async {
    return repository.deleteActivity(params.id);
  }
}

class DeleteActivityParams {
  DeleteActivityParams({required this.id});
  final String id;
}
