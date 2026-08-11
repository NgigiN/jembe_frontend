import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';

class CostCategoryRepositoryImpl implements CostCategoryRepository {
  CostCategoryRepositoryImpl({required this.remoteDataSource});
  final CostCategoryRemoteDataSource remoteDataSource;

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
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
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
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCostCategory(String id) async {
    try {
      await remoteDataSource.deleteCostCategory(id);
      return const Right(null);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
