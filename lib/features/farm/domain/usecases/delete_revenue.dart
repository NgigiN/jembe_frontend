import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';

class DeleteRevenue implements UseCase<void, String> {
  DeleteRevenue(this.repository);
  final RevenueRepository repository;

  @override
  Future<Either<Failure, void>> call(String id) async {
    return repository.deleteRevenue(id);
  }
}
