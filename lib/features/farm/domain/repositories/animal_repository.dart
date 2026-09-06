import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalRepository {
  Future<Either<Failure, List<Animal>>> getAnimals();

  /// Reactive stream of animals.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`AnimalLocalDataSource.watchAnimals`), with every [Animal.id]
  /// equal to the row's stable `clientUuid` — see `AnimalRepositoryImpl` for
  /// why presentation keys on `clientUuid` rather than the server id. When
  /// the flag is off, this is unused by the app today; it still returns a
  /// single-emission stream so callers compile against one contract either
  /// way.
  Stream<List<Animal>> watchAnimals();
  Future<Either<Failure, Animal>> addAnimal(Animal animal);
  Future<Either<Failure, Animal>> updateAnimal(Animal animal);
  Future<Either<Failure, void>> deleteAnimal(String id);
}
