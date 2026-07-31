import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

class SeasonRepositoryImpl implements SeasonRepository {
  SeasonRepositoryImpl({required this.remoteDataSource});
  final SeasonRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Season>>> getSeasons() async {
    try {
      final seasons = await remoteDataSource.getSeasons();
      return Right(seasons);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Season>> addSeason(Season season) async {
    try {
      // Convert Season entity to SeasonModel
      final seasonModel = SeasonModel(
        id: season.id,
        userId: season.userId,
        name: season.name,
        plantId: season.plantId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await remoteDataSource.addSeason(seasonModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSeason(String id) async {
    try {
      await remoteDataSource.deleteSeason(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Season>> updateSeason(Season season) async {
    try {
      final seasonModel = SeasonModel(
        id: season.id,
        userId: season.userId,
        name: season.name,
        plantId: season.plantId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final result = await remoteDataSource.updateSeason(seasonModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
