import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';

class GetHerds implements UseCase<List<Herd>, NoParams> {
  GetHerds(this.repository);
  final HerdRepository repository;

  @override
  Future<Either<Failure, List<Herd>>> call(NoParams params) async {
    return repository.getHerds();
  }
}
