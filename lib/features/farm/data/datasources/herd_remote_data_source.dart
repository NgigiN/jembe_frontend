import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';

abstract class HerdRemoteDataSource {
  Future<List<HerdModel>> getHerds();
  Future<HerdModel> addHerd(HerdModel herd);
  Future<HerdModel> updateHerd(HerdModel herd);
  Future<void> deleteHerd(String id);
}

class HerdRemoteDataSourceImpl implements HerdRemoteDataSource {
  HerdRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<HerdModel>> getHerds() async {
    try {
      final response = await dio.get('/api/v1/herds');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map((json) => HerdModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        var errorMsg = 'Failed to load herds';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to load herds';
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
  Future<HerdModel> addHerd(HerdModel herd) async {
    try {
      final response = await dio.post('/api/v1/herds', data: herd.toJson());

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to add herd';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to add herd';
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
  Future<HerdModel> updateHerd(HerdModel herd) async {
    try {
      final response = await dio.put(
        '/api/v1/herds/${herd.id}',
        data: herd.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to update herd';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to update herd';
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
  Future<void> deleteHerd(String id) async {
    try {
      final response = await dio.delete('/api/v1/herds/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        var errorMsg = 'Failed to delete herd';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to delete herd';
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
