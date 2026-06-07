import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/infrastructure_model.dart';

abstract class InfrastructureRemoteDataSource {
  Future<List<InfrastructureModel>> getInfrastructures();
  Future<InfrastructureModel> addInfrastructure(InfrastructureModel infrastructure);
  Future<InfrastructureModel> updateInfrastructure(InfrastructureModel infrastructure);
  Future<void> deleteInfrastructure(String id);
}

class InfrastructureRemoteDataSourceImpl implements InfrastructureRemoteDataSource {
  InfrastructureRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<InfrastructureModel>> getInfrastructures() async {
    try {
      final response = await dio.get('/api/v1/infrastructure');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map((json) => InfrastructureModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        var errorMsg = 'Failed to load infrastructure';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to load infrastructure';
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
  Future<InfrastructureModel> addInfrastructure(InfrastructureModel infrastructure) async {
    try {
      final response = await dio.post(
        '/api/v1/infrastructure',
        data: infrastructure.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return InfrastructureModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to add infrastructure';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to add infrastructure';
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
  Future<InfrastructureModel> updateInfrastructure(InfrastructureModel infrastructure) async {
    try {
      final response = await dio.put(
        '/api/v1/infrastructure/${infrastructure.id}',
        data: infrastructure.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return InfrastructureModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to update infrastructure';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to update infrastructure';
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
  Future<void> deleteInfrastructure(String id) async {
    try {
      final response = await dio.delete('/api/v1/infrastructure/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        var errorMsg = 'Failed to delete infrastructure';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to delete infrastructure';
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
