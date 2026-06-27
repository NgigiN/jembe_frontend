import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';

abstract class CostCategoryRepository {
  Future<Either<Failure, List<CostCategory>>> getCostCategories({
    String? type,
    String? category,
  });

  Future<Either<Failure, bool>> addCostCategory({
    required String name,
    required String type,
    required String category,
  });

  Future<Either<Failure, void>> deleteCostCategory(String id);
}
