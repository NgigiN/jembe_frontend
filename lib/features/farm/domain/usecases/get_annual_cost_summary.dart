import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';

class GetAnnualCostSummary
    implements UseCase<List<MonthlySummary>, GetAnnualCostSummaryParams> {

  GetAnnualCostSummary(this.repository);
  final AnalysisRepository repository;

  @override
  Future<Either<Failure, List<MonthlySummary>>> call(
    GetAnnualCostSummaryParams params,
  ) async {
    return repository.getAnnualCostSummary(params.startDate, params.endDate);
  }
}

class GetAnnualCostSummaryParams extends Equatable {
  const GetAnnualCostSummaryParams({
    required this.startDate,
    required this.endDate,
  });
  final DateTime startDate;
  final DateTime endDate;

  @override
  List<Object?> get props => [startDate, endDate];
}
