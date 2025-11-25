import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activity_repository.dart';
import 'get_activities_params.dart';

class GetActivities implements UseCase<List<Activity>, GetActivitiesParams> {
  final ActivityRepository repository;

  GetActivities(this.repository);

  @override
  Future<Either<Failure, List<Activity>>> call(GetActivitiesParams params) async {
    return await repository.getActivities(sourceType: params.sourceType);
  }
}
