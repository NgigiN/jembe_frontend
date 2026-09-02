import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';

abstract class AnimalRemoteDataSource {
  Future<List<AnimalModel>> getAnimals();
  Future<AnimalModel> addAnimal(AnimalModel animal);
  Future<AnimalModel> updateAnimal(AnimalModel animal);
  Future<void> deleteAnimal(String id);
}

class AnimalRemoteDataSourceImpl implements AnimalRemoteDataSource {
  AnimalRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<AnimalModel>> getAnimals() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/animals');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map((json) => AnimalModel.fromJson(json as Map<String, dynamic>))
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
  Future<AnimalModel> addAnimal(AnimalModel animal) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/animals',
        data: animal.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AnimalModel.fromJson(data);
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
  Future<AnimalModel> updateAnimal(AnimalModel animal) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/animals/${animal.id}',
        data: animal.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AnimalModel.fromJson(data);
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
  Future<void> deleteAnimal(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/animals/$id');

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
