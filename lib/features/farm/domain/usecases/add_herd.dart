import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';

class AddHerd {
  AddHerd(this.repository);
  final HerdRepository repository;

  Future<Either<Failure, Herd>> call(
    String name,
    String animalTypeId,
    String location,
    String userId,
    int initialHeadCount, {
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    return repository.addHerd(
      name,
      animalTypeId,
      location,
      userId,
      initialHeadCount,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
