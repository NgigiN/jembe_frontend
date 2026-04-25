import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';

abstract class HerdRepository {
  Future<Either<Failure, List<Herd>>> getHerds();
  Future<Either<Failure, Herd>> addHerd(
    String name,
    String animalTypeId,
    String location,
    String userId,
  );
  Future<Either<Failure, Herd>> updateHerd(
    String id,
    String name,
    String animalTypeId,
    String location,
  );
  Future<Either<Failure, void>> deleteHerd(String id);
}
