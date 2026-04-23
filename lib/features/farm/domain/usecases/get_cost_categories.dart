import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/cost_category.dart';
import '../repositories/cost_category_repository.dart';

class GetCostCategories
    implements UseCase<List<CostCategory>, GetCostCategoriesParams> {
  final CostCategoryRepository repository;

  GetCostCategories(this.repository);

  @override
  Future<Either<Failure, List<CostCategory>>> call(
    GetCostCategoriesParams params,
  ) async {
    return await repository.getCostCategories(
      type: params.type,
      category: params.category,
    );
  }
}

class GetCostCategoriesParams extends Equatable {
  final String? type;
  final String? category;

  const GetCostCategoriesParams({this.type, this.category});

  @override
  List<Object?> get props => [type, category];
}
