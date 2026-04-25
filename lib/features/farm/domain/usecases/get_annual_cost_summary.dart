import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';

class GetAnnualCostSummary implements UseCase<List<MonthlySummary>, NoParams> {

  GetAnnualCostSummary(this.repository);
  final AnalysisRepository repository;

  @override
  Future<Either<Failure, List<MonthlySummary>>> call(NoParams params) async {
    return repository.getAnnualCostSummary();
  }
}
