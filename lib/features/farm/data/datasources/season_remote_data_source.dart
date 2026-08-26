import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

abstract class SeasonRemoteDataSource {
  Future<List<SeasonModel>> getSeasons();
  Future<SeasonModel> addSeason(SeasonModel season);
  Future<SeasonModel> updateSeason(SeasonModel season);
  Future<void> deleteSeason(String id);
}

class SeasonRemoteDataSourceImpl implements SeasonRemoteDataSource {
  SeasonRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<SeasonModel>> getSeasons() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/seasons');

      appLogger.debug(
        LogCategory.http,
        'Seasons API Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          final items = data;
          appLogger.info(LogCategory.farm, 'Found ${items.length} seasons');
          return items
              .map((json) => SeasonModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        var errorMsg =
            'Failed to load seasons (Status: ${response.statusCode})';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<SeasonModel> addSeason(SeasonModel season) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/seasons',
        data: {
          'name': season.name,
          'plant_id': int.tryParse(season.plantId) ?? 0,
          'land_id': int.tryParse(season.landId) ?? 0,
          'start_date': season.startDate.toUtc().toIso8601String(),
          'end_date': season.endDate?.toUtc().toIso8601String(),
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return SeasonModel.fromJson(data);
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
  Future<SeasonModel> updateSeason(SeasonModel season) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/seasons/${season.id}',
        data: {
          'name': season.name,
          'plant_id': int.tryParse(season.plantId) ?? 0,
          'land_id': int.tryParse(season.landId) ?? 0,
          'start_date': season.startDate.toUtc().toIso8601String(),
          'end_date': season.endDate?.toUtc().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return SeasonModel.fromJson(data);
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
  Future<void> deleteSeason(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/seasons/$id');

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
