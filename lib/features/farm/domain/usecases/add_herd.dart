import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/herd.dart';
import '../repositories/herd_repository.dart';

class AddHerd {
  final HerdRepository repository;

  AddHerd(this.repository);

  Future<Either<Failure, Herd>> call(String name, String animalTypeId, String location, String userId) async {
    return await repository.addHerd(name, animalTypeId, location, userId);
  }
}

