import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities_params.dart';

class GetActivities implements UseCase<List<Activity>, GetActivitiesParams> {
  GetActivities(this.repository);
  final ActivityRepository repository;

  @override
  Future<Either<Failure, List<Activity>>> call(
    GetActivitiesParams params,
  ) async {
    return repository.getActivities(sourceType: params.sourceType);
  }
}
