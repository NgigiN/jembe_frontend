import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/cost_breakdown.dart';
import '../repositories/analysis_repository.dart';

class GetCostBreakdown implements UseCase<List<CostBreakdown>, NoParams> {
  final AnalysisRepository repository;

  GetCostBreakdown(this.repository);

  @override
  Future<Either<Failure, List<CostBreakdown>>> call(NoParams params) async {
    return await repository.getCostBreakdownByInputType();
  }
}
