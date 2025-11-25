import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/herd.dart';
import '../repositories/herd_repository.dart';

class UpdateHerd {
  final HerdRepository repository;

  UpdateHerd(this.repository);

  Future<Either<Failure, Herd>> call(String id, String name, String animalTypeId, String location) async {
    return await repository.updateHerd(id, name, animalTypeId, location);
  }
}

