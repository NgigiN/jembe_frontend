import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalRepository {
  /// [limit]/[cursor] drive the online infinite-scroll list path (P3-02a):
  /// they are threaded through only when the offline flag is off. The offline
  /// (`watchAnimals`) path ignores them — it mirrors the whole local store.
  Future<Either<Failure, List<Animal>>> getAnimals({int? limit, int? cursor});

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
