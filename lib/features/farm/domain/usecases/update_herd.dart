import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';

class UpdateHerd {
  UpdateHerd(this.repository);
  final HerdRepository repository;

  Future<Either<Failure, Herd>> call(
    String id,
    String name,
    String animalTypeId,
    String location,
    int initialHeadCount, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    return repository.updateHerd(
      id,
      name,
      animalTypeId,
      location,
      initialHeadCount,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
