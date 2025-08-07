import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/total_costs_by_season.dart';
import '../repositories/analysis_repository.dart';

class GetTotalCostsBySeason
    implements UseCase<List<TotalCostsBySeason>, NoParams> {
  final AnalysisRepository repository;

  GetTotalCostsBySeason(this.repository);

  @override
  Future<Either<Failure, List<TotalCostsBySeason>>> call(
    NoParams params,
  ) async {
    return await repository.getTotalCostsBySeason();
  }
}
