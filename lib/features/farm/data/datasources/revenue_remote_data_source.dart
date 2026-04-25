import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';

abstract class RevenueRemoteDataSource {
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<RevenueModel> getRevenueById(String id);
  Future<RevenueModel> addRevenue(RevenueModel revenue);
  Future<RevenueModel> updateRevenue(RevenueModel revenue);
  Future<void> deleteRevenue(String id);
}

class RevenueRemoteDataSourceImpl implements RevenueRemoteDataSource {
  RevenueRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (source != null) {
        queryParams['source'] = source;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final response = await dio.get(
        '/api/v1/revenue',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map(
                (json) => RevenueModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
        return [];
      } else {
        var errorMsg = 'Failed to load revenues';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to load revenues';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<RevenueModel> getRevenueById(String id) async {
    try {
      final response = await dio.get('/api/v1/revenue/$id');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return RevenueModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to load revenue';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to load revenue';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<RevenueModel> addRevenue(RevenueModel revenue) async {
    try {
      final response = await dio.post(
        '/api/v1/revenue',
        data: revenue.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return RevenueModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to add revenue';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to add revenue';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<RevenueModel> updateRevenue(RevenueModel revenue) async {
    try {
      final response = await dio.put(
        '/api/v1/revenue/${revenue.id}',
        data: revenue.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return RevenueModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to update revenue';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to update revenue';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<void> deleteRevenue(String id) async {
    try {
      final response = await dio.delete('/api/v1/revenue/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        var errorMsg = 'Failed to delete revenue';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to delete revenue';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }
}
