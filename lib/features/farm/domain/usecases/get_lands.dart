import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/land.dart';
import '../repositories/land_repository.dart';

class GetLands implements UseCase<List<Land>, NoParams> {
  final LandRepository repository;

  GetLands(this.repository);

  @override
  Future<Either<Failure, List<Land>>> call(NoParams params) async {
    return await repository.getLands();
  }
}
