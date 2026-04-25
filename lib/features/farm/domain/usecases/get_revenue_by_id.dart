import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';

class GetRevenueById implements UseCase<Revenue, String> {
  GetRevenueById(this.repository);
  final RevenueRepository repository;

  @override
  Future<Either<Failure, Revenue>> call(String id) async {
    return repository.getRevenueById(id);
  }
}
