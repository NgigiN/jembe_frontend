import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/farm_detailed_cost.dart';
import '../repositories/analysis_repository.dart';

class GetTotalCostsBySeason
    implements UseCase<FarmDetailedCost, NoParams> {
  final AnalysisRepository repository;

  GetTotalCostsBySeason(this.repository);

  @override
  Future<Either<Failure, FarmDetailedCost>> call(
    NoParams params,
  ) async {
    return await repository.getTotalCostsBySeason();
  }
}
