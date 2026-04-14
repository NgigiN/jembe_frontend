import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/season_model.dart';

abstract class SeasonRemoteDataSource {
  Future<List<SeasonModel>> getSeasons();
  Future<SeasonModel> addSeason(SeasonModel season);
  Future<SeasonModel> updateSeason(SeasonModel season);
  Future<void> deleteSeason(String id);
}

class SeasonRemoteDataSourceImpl implements SeasonRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  SeasonRemoteDataSourceImpl({required this.dio, required this.baseUrl});

  @override
  Future<List<SeasonModel>> getSeasons() async {
    try {
      final response = await dio.get('/api/v1/seasons');

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
        String errorMsg =
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
      appLogger.error(LogCategory.http, 'Error in getSeasons', e);
      String errorMsg = 'Network error';
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
  Future<SeasonModel> addSeason(SeasonModel season) async {
    try {
      final response = await dio.post(
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
        String errorMsg = 'Failed to add season';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to add season';
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
  Future<SeasonModel> updateSeason(SeasonModel season) async {
    try {
      final response = await dio.put(
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
        String errorMsg = 'Failed to update season';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to update season';
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
  Future<void> deleteSeason(String id) async {
    try {
      final response = await dio.delete('/api/v1/seasons/$id');

      if (response.statusCode != 200) {
        String errorMsg = 'Failed to delete season';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to delete season';
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
