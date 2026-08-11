import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';

class DeleteCostCategory implements UseCase<void, DeleteCostCategoryParams> {
  DeleteCostCategory(this.repository);
  final CostCategoryRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteCostCategoryParams params) async {
    return repository.deleteCostCategory(params.id);
  }
}

class DeleteCostCategoryParams {
  DeleteCostCategoryParams({required this.id});
  final String id;
}