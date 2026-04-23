import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/cost_category.dart';
import '../../domain/repositories/cost_category_repository.dart';
import '../datasources/cost_category_remote_data_source.dart';

class CostCategoryRepositoryImpl implements CostCategoryRepository {
  final CostCategoryRemoteDataSource remoteDataSource;

  CostCategoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CostCategory>>> getCostCategories({
    String? type,
    String? category,
  }) async {
    try {
      final remoteCategories = await remoteDataSource.getCostCategories(
        type: type,
        category: category,
      );
      return Right(remoteCategories);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> addCostCategory({
    required String name,
    required String type,
    required String category,
  }) async {
    try {
      final success = await remoteDataSource.addCostCategory(
        name: name,
        type: type,
        category: category,
      );
      return Right(success);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
