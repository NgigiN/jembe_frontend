import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/revenue.dart';
import '../repositories/revenue_repository.dart';
import 'get_revenues_params.dart';

class GetRevenues implements UseCase<List<Revenue>, GetRevenuesParams> {
  final RevenueRepository repository;

  GetRevenues(this.repository);

  @override
  Future<Either<Failure, List<Revenue>>> call(GetRevenuesParams params) async {
    return await repository.getRevenues(
      source: params.source,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}


