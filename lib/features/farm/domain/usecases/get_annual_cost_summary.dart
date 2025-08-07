import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/annual_cost_summary.dart';
import '../repositories/analysis_repository.dart';

class GetAnnualCostSummary
    implements UseCase<List<AnnualCostSummary>, NoParams> {
  final AnalysisRepository repository;

  GetAnnualCostSummary(this.repository);

  @override
  Future<Either<Failure, List<AnnualCostSummary>>> call(NoParams params) async {
    return await repository.getAnnualCostSummary();
  }
}
