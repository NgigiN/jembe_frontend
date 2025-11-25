import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/herd.dart';
import '../repositories/herd_repository.dart';

class GetHerds implements UseCase<List<Herd>, NoParams> {
  final HerdRepository repository;

  GetHerds(this.repository);

  @override
  Future<Either<Failure, List<Herd>>> call(NoParams params) async {
    return await repository.getHerds();
  }
}

