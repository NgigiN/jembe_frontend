import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/activity.dart';

abstract class ActivityRepository {
  Future<Either<Failure, List<Activity>>> getActivities({String? sourceType});
  Future<Either<Failure, Activity>> addActivity(Activity activity);
  Future<Either<Failure, Activity>> updateActivity(Activity activity);
  Future<Either<Failure, void>> deleteActivity(String id);
}
