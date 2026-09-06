import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
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
    String? clientUuid,
  });

  Future<void> deleteCostCategory(String id);
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
      final response = await dio.get<dynamic>(
        '/api/v1/cost-categories',
        queryParameters: {
          if (type != null) 'type': type,
          if (category != null) 'category': category,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>? ?? [];
        return data.map((json) => CostCategoryModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<bool> addCostCategory({
    required String name,
    required String type,
    required String category,
    String? clientUuid,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/cost-categories',
        data: {
          'name': name,
          'type': type,
          'category': category,
          // Offline sync path only (Task 9a): P1's create idempotency key is
          // (user_id, client_uuid) — a retried push (same clientUuid)
          // resolves to the already-created row server-side instead of
          // duplicating it. Omitted (and the wire body unchanged) when the
          // flag-off repo calls this without a clientUuid.
          if (clientUuid != null) 'client_uuid': clientUuid,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteCostCategory(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/cost-categories/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }
}
