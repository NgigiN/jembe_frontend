import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';

class AddCostCategory implements UseCase<bool, AddCostCategoryParams> {
  AddCostCategory(this.repository);
  final CostCategoryRepository repository;

  @override
  Future<Either<Failure, bool>> call(AddCostCategoryParams params) async {
    return repository.addCostCategory(
      name: params.name,
      type: params.type,
      category: params.category,
    );
  }
}

class AddCostCategoryParams extends Equatable {
  const AddCostCategoryParams({
    required this.name,
    required this.type,
    required this.category,
  });
  final String name;
  final String type;
  final String category;

  @override
  List<Object?> get props => [name, type, category];
}
