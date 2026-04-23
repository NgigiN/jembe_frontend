import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/monthly_summary.dart';
import '../repositories/analysis_repository.dart';

class GetAnnualCostSummary implements UseCase<List<MonthlySummary>, NoParams> {
  final AnalysisRepository repository;

  GetAnnualCostSummary(this.repository);

  @override
  Future<Either<Failure, List<MonthlySummary>>> call(NoParams params) async {
    return await repository.getAnnualCostSummary();
  }
}
