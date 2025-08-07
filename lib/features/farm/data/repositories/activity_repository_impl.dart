import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/activity_remote_data_source.dart';
import '../models/activity_model.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final ActivityRemoteDataSource remoteDataSource;

  ActivityRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Activity>>> getActivities() async {
    try {
      final activities = await remoteDataSource.getActivities();
      return Right(activities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Activity>> addActivity(Activity activity) async {
    try {
      // Convert Activity entity to ActivityModel
      final activityModel = ActivityModel(
        id: activity.id,
        seasonId: activity.seasonId,
        type: activity.type,
        date: activity.date,
        cost: activity.cost,
        details: activity.details,
        createdAt: activity.createdAt,
        updatedAt: activity.updatedAt,
      );

      final result = await remoteDataSource.addActivity(activityModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Activity>> updateActivity(Activity activity) async {
    try {
      final activityModel = await remoteDataSource.updateActivity(
        activity as dynamic,
      );
      return Right(activityModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteActivity(String id) async {
    try {
      await remoteDataSource.deleteActivity(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
