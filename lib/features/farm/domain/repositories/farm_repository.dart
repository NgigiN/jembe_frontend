import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/land.dart';
import '../entities/plant.dart';
import '../entities/season.dart';
import '../entities/activity.dart';

abstract class FarmRepository {
  Future<Either<Failure, List<Land>>> getLands();
  Future<Either<Failure, Land>> addLand(String name);
  Future<Either<Failure, Land>> updateLand(String id, String name);
  Future<Either<Failure, List<Plant>>> getPlants();
  Future<Either<Failure, Plant>> addPlant(String name);
  Future<Either<Failure, Plant>> updatePlant(String id, String name);
  Future<Either<Failure, List<Season>>> getSeasons();
  Future<Either<Failure, Season>> addSeason(String name);
  Future<Either<Failure, Season>> updateSeason(String id, String name);
  Future<Either<Failure, List<Activity>>> getActivities();
  Future<Either<Failure, Activity>> addActivity(String description);
}
