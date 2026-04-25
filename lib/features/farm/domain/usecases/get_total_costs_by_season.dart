import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';

class GetTotalCostsBySeason implements UseCase<FarmDetailedCost, NoParams> {
  GetTotalCostsBySeason(this.repository);
  final AnalysisRepository repository;

  @override
  Future<Either<Failure, FarmDetailedCost>> call(NoParams params) async {
    return repository.getTotalCostsBySeason();
  }
}
