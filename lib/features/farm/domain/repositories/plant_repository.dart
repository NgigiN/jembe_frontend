import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';

abstract class PlantRepository {
  Future<Either<Failure, List<Plant>>> getPlants();

  /// Reactive stream of plants.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`PlantLocalDataSource.watchPlants`), with every [Plant.id]
  /// equal to the row's stable `clientUuid` — see `PlantRepositoryImpl` for
  /// why presentation keys on `clientUuid` rather than the server id. When
  /// the flag is off, this is unused by the app today; it still returns a
  /// single-emission stream so callers compile against one contract either
  /// way.
  Stream<List<Plant>> watchPlants();
  Future<Either<Failure, Plant>> addPlant(Plant plant);
  Future<Either<Failure, Plant>> updatePlant(Plant plant);
  Future<Either<Failure, void>> deletePlant(String id);
}
