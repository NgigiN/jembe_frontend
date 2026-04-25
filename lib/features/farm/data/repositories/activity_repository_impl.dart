import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl({required this.remoteDataSource});
  final ActivityRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Activity>>> getActivities({
    String? sourceType,
  }) async {
    try {
      final activities = await remoteDataSource.getActivities(
        sourceType: sourceType,
      );
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
        sourceType: activity.sourceType,
        sourceId: activity.sourceId,
        animalId: activity.animalId,
        type: activity.type,
        date: activity.date,
        cost: activity.cost,
        details: activity.details,
        notes: activity.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
      // Convert Activity entity to ActivityModel
      final activityModel = ActivityModel(
        id: activity.id,
        sourceType: activity.sourceType,
        sourceId: activity.sourceId,
        animalId: activity.animalId,
        type: activity.type,
        date: activity.date,
        cost: activity.cost,
        details: activity.details,
        notes: activity.notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await remoteDataSource.updateActivity(activityModel);
      return Right(result);
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
