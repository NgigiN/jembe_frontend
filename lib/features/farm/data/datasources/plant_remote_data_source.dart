import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';

abstract class PlantRemoteDataSource {
  Future<List<PlantModel>> getPlants();
  Future<PlantModel> addPlant(PlantModel plant);
  Future<PlantModel> updatePlant(PlantModel plant);
  Future<void> deletePlant(String id);
}

class PlantRemoteDataSourceImpl implements PlantRemoteDataSource {
  PlantRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<PlantModel>> getPlants() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/plants');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map((json) => PlantModel.fromJson(json as Map<String, dynamic>))
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
  Future<PlantModel> addPlant(PlantModel plant) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/plants',
        data: {'name': plant.name, 'variety': plant.variety},
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
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
  Future<PlantModel> updatePlant(PlantModel plant) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/plants/${plant.id}',
        data: {'name': plant.name, 'variety': plant.variety},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
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
  Future<void> deletePlant(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/plants/$id');

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
