import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';

abstract class CostCategoryRemoteDataSource {
  Future<List<CostCategoryModel>> getCostCategories({
    String? type,
    String? category,
  });

  Future<bool> addCostCategory({
    required String name,
    required String type,
    required String category,
  });
}

class CostCategoryRemoteDataSourceImpl implements CostCategoryRemoteDataSource {
  CostCategoryRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<CostCategoryModel>> getCostCategories({
    String? type,
    String? category,
  }) async {
    try {
      final response = await dio.get(
        '/api/v1/cost-categories',
        queryParameters: {
          if (type != null) 'type': type,
          if (category != null) 'category': category,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => CostCategoryModel.fromJson(json)).toList();
      } else {
        throw const ServerException('Failed to load cost categories');
      }
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Failed to load cost categories');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<bool> addCostCategory({
    required String name,
    required String type,
    required String category,
  }) async {
    try {
      final response = await dio.post(
        '/api/v1/cost-categories',
        data: {'name': name, 'type': type, 'category': category},
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Failed to add cost category');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
