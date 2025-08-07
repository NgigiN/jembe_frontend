import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/season_repository.dart';
import '../datasources/season_remote_data_source.dart';
import '../models/season_model.dart';

class SeasonRepositoryImpl implements SeasonRepository {
  final SeasonRemoteDataSource remoteDataSource;

  SeasonRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Season>>> getSeasons() async {
    try {
      final seasons = await remoteDataSource.getSeasons();
      return Right(seasons);
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
        cropId: season.cropId,
        landId: season.landId,
        startDate: season.startDate,
        endDate: season.endDate,
        createdAt: season.createdAt,
        updatedAt: season.updatedAt,
      );

      final result = await remoteDataSource.addSeason(seasonModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Season>> updateSeason(Season season) async {
    try {
      final seasonModel = await remoteDataSource.updateSeason(
        season as dynamic,
      );
      return Right(seasonModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSeason(String id) async {
    try {
      await remoteDataSource.deleteSeason(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
