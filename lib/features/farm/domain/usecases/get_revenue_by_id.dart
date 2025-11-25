import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/revenue.dart';
import '../repositories/revenue_repository.dart';

class GetRevenueById implements UseCase<Revenue, String> {
  final RevenueRepository repository;

  GetRevenueById(this.repository);

  @override
  Future<Either<Failure, Revenue>> call(String id) async {
    return await repository.getRevenueById(id);
  }
}


