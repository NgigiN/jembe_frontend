import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
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
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
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
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
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
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteLand(String id) async {
    try {
      final response = await dio.delete('/api/v1/lands/$id');

      if (response.statusCode != 200) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }
}
