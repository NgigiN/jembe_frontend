import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';

class GetCostCategories
    implements UseCase<List<CostCategory>, GetCostCategoriesParams> {
  GetCostCategories(this.repository);
  final CostCategoryRepository repository;

  @override
  Future<Either<Failure, List<CostCategory>>> call(
    GetCostCategoriesParams params,
  ) async {
    return repository.getCostCategories(
      type: params.type,
      category: params.category,
    );
  }
}

class GetCostCategoriesParams extends Equatable {
  const GetCostCategoriesParams({this.type, this.category});
  final String? type;
  final String? category;

  @override
  List<Object?> get props => [type, category];
}
