import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activity_repository.dart';

class UpdateActivity implements UseCase<Activity, UpdateActivityParams> {
  final ActivityRepository repository;

  UpdateActivity(this.repository);

  @override
  Future<Either<Failure, Activity>> call(UpdateActivityParams params) async {
    return await repository.updateActivity(params.activity);
  }
}

class UpdateActivityParams {
  final Activity activity;

  UpdateActivityParams({required this.activity});
}
