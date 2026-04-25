import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

abstract class LandRemoteDataSource {
  Future<List<LandModel>> getLands();
  Future<LandModel> addLand(LandModel land);
  Future<LandModel> updateLand(LandModel land);
  Future<void> deleteLand(String id);
}

class LandRemoteDataSourceImpl implements LandRemoteDataSource {
  LandRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<LandModel>> getLands() async {
    try {
      final response = await dio.get('/api/v1/lands');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map((json) => LandModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        var errorMsg = 'Failed to load lands';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to load lands';
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
  Future<LandModel> addLand(LandModel land) async {
    try {
      final response = await dio.post(
        '/api/v1/lands',
        data: {
          'name': land.name,
          'size': land.size,
          'location': land.location,
          'soil_type': land.soilType,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return LandModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to add land';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to add land';
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
  Future<LandModel> updateLand(LandModel land) async {
    try {
      final response = await dio.put(
        '/api/v1/lands/${land.id}',
        data: {
          'name': land.name,
          'size': land.size,
          'location': land.location,
          'soil_type': land.soilType,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return LandModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to update land';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to update land';
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
  Future<void> deleteLand(String id) async {
    try {
      final response = await dio.delete('/api/v1/lands/$id');

      if (response.statusCode != 200) {
        var errorMsg = 'Failed to delete land';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to delete land';
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
