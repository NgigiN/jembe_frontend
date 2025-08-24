import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/activity_repository.dart';

class DeleteActivity implements UseCase<void, DeleteActivityParams> {
  final ActivityRepository repository;

  DeleteActivity(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteActivityParams params) async {
    return await repository.deleteActivity(params.id);
  }
}

class DeleteActivityParams {
  final String id;

  DeleteActivityParams({required this.id});
}
