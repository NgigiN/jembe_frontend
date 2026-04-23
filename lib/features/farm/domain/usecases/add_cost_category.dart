import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/cost_category_repository.dart';

class AddCostCategory implements UseCase<bool, AddCostCategoryParams> {
  final CostCategoryRepository repository;

  AddCostCategory(this.repository);

  @override
  Future<Either<Failure, bool>> call(AddCostCategoryParams params) async {
    return await repository.addCostCategory(
      name: params.name,
      type: params.type,
      category: params.category,
    );
  }
}

class AddCostCategoryParams extends Equatable {
  final String name;
  final String type;
  final String category;

  const AddCostCategoryParams({
    required this.name,
    required this.type,
    required this.category,
  });

  @override
  List<Object?> get props => [name, type, category];
}
