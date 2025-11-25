import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/herd_repository.dart';

class DeleteHerd {
  final HerdRepository repository;

  DeleteHerd(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteHerd(id);
  }
}

