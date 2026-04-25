import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';

class UpdateActivity implements UseCase<Activity, UpdateActivityParams> {
  UpdateActivity(this.repository);
  final ActivityRepository repository;

  @override
  Future<Either<Failure, Activity>> call(UpdateActivityParams params) async {
    return repository.updateActivity(params.activity);
  }
}

class UpdateActivityParams {
  UpdateActivityParams({required this.activity});
  final Activity activity;
}
