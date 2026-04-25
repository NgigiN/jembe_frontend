import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenues_params.dart';

class GetRevenues implements UseCase<List<Revenue>, GetRevenuesParams> {
  GetRevenues(this.repository);
  final RevenueRepository repository;

  @override
  Future<Either<Failure, List<Revenue>>> call(GetRevenuesParams params) async {
    return repository.getRevenues(
      source: params.source,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}
