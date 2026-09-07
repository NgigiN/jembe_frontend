import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/plant_model.dart';

abstract class PlantRemoteDataSource {
  /// Fetches all plants, or — when [updatedSince] is given — only those the
  /// server has changed strictly after that instant (used by the sync
  /// pull phase). Existing no-arg callers (the flag-off repo path) are
  /// unaffected.
  Future<List<PlantModel>> getPlants({DateTime? updatedSince});
  Future<PlantModel> addPlant(PlantModel plant);
  Future<PlantModel> updatePlant(PlantModel plant);
  Future<void> deletePlant(String id);
}

class PlantRemoteDataSourceImpl implements PlantRemoteDataSource {
  PlantRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<PlantModel>> getPlants({DateTime? updatedSince}) async {
    try {
      final queryParams = updatedSince != null
          ? {'updated_since': updatedSince.toUtc().toIso8601String()}
          : null;

      final response = await dio.get<dynamic>(
        '/api/v1/plants',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map((json) => PlantModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
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
        data: {
          'name': plant.name,
          'variety': plant.variety,
          // Required for the offline sync path: P1's create endpoint keys
          // its idempotency check on (user_id, client_uuid) — a retried
          // push (same clientUuid) returns the ALREADY-created row instead
          // of duplicating it. Harmless for the flag-off legacy path too:
          // `PlantModel.create` always mints a fresh clientUuid there, so
          // this is just an unused-but-valid extra field server-side.
          'client_uuid': plant.clientUuid,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
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
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
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
