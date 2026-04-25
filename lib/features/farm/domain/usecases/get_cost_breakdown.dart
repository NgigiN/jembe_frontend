import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';

class GetCostBreakdown implements UseCase<List<CostBreakdown>, NoParams> {
  GetCostBreakdown(this.repository);
  final AnalysisRepository repository;

  @override
  Future<Either<Failure, List<CostBreakdown>>> call(NoParams params) async {
    return repository.getCostBreakdownByInputType();
  }
}
