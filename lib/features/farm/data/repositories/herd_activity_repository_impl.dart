import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_activity_repository.dart';

class HerdActivityRepositoryImpl implements HerdActivityRepository {
  HerdActivityRepositoryImpl({required this.remoteDataSource});
  final HerdActivityRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, HerdActivity>> addHerdActivity(
    String herdId,
    String activityType,
    int count,
    DateTime date,
    String? notes,
  ) async {
    try {
      final model = HerdActivityModel.create(
        herdId: herdId,
        activityType: activityType,
        count: count,
        date: date,
        notes: notes,
      );
      final result = await remoteDataSource.addHerdActivity(herdId, model);
      return Right(result);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
