import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/land.dart';
import '../../domain/entities/crop.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/farm_repository.dart';
import '../datasources/farm_remote_data_source.dart';

class FarmRepositoryImpl implements FarmRepository {
  final FarmRemoteDataSource remoteDataSource;

  FarmRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Land>>> getLands() async {
    try {
      final lands = await remoteDataSource.getLands();
      return Right(lands);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Land>> addLand(String name) async {
    try {
      final land = await remoteDataSource.addLand(name);
      return Right(land);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Land>> updateLand(String id, String name) async {
    try {
      final land = await remoteDataSource.updateLand(id, name);
      return Right(land);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Crop>>> getCrops() async {
    try {
      final crops = await remoteDataSource.getCrops();
      return Right(crops);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Crop>> addCrop(String name) async {
    try {
      final crop = await remoteDataSource.addCrop(name);
      return Right(crop);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Crop>> updateCrop(String id, String name) async {
    try {
      final crop = await remoteDataSource.updateCrop(id, name);
      return Right(crop);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Season>>> getSeasons() async {
    try {
      final seasons = await remoteDataSource.getSeasons();
      return Right(seasons);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Season>> addSeason(String name) async {
    try {
      final season = await remoteDataSource.addSeason(name);
      return Right(season);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Season>> updateSeason(String id, String name) async {
    try {
      final season = await remoteDataSource.updateSeason(id, name);
      return Right(season);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<Activity>>> getActivities() async {
    try {
      final activities = await remoteDataSource.getActivities();
      return Right(activities);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Activity>> addActivity(String description) async {
    try {
      final activity = await remoteDataSource.addActivity(description);
      return Right(activity);
    } on ServerException {
      return Left(ServerFailure());
    }
  }
}
