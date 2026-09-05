import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';

abstract class AnimalTypeRepository {
  Future<Either<Failure, List<AnimalType>>> getAnimalTypes();

  /// Reactive stream of animal types.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`AnimalTypeLocalDataSource.watchAnimalTypes`), with every
  /// [AnimalType.id] equal to the row's stable `clientUuid` — see
  /// `AnimalTypeRepositoryImpl` for why presentation keys on `clientUuid`
  /// rather than the server id. When the flag is off, this is unused by the
  /// app today; it still returns a single-emission stream so callers
  /// compile against one contract either way.
  Stream<List<AnimalType>> watchAnimalTypes();
  Future<Either<Failure, AnimalType>> getAnimalType(String id);
  Future<Either<Failure, AnimalType>> addAnimalType(
    String name,
    String? notes,
    String userId,
  );
  Future<Either<Failure, AnimalType>> updateAnimalType(
    String id,
    String name,
    String? notes,
  );
  Future<Either<Failure, void>> deleteAnimalType(String id);
}
