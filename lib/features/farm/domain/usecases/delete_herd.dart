import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';

class DeleteHerd {
  DeleteHerd(this.repository);
  final HerdRepository repository;

  Future<Either<Failure, void>> call(String id) async {
    return repository.deleteHerd(id);
  }
}
