import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

abstract class SeasonRemoteDataSource {
  /// Fetches all seasons, or — when [updatedSince] is given — only those the
  /// server has changed strictly after that instant (used by the sync
  /// pull phase). Existing no-arg callers (the flag-off repo path) are
  /// unaffected.
  Future<List<SeasonModel>> getSeasons({DateTime? updatedSince});
  Future<SeasonModel> addSeason(SeasonModel season);
  Future<SeasonModel> updateSeason(SeasonModel season);
  Future<void> deleteSeason(String id);
}

class SeasonRemoteDataSourceImpl implements SeasonRemoteDataSource {
  SeasonRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<SeasonModel>> getSeasons({DateTime? updatedSince}) async {
    try {
      final queryParams = updatedSince != null
          ? {'updated_since': updatedSince.toUtc().toIso8601String()}
          : null;

      final response = await dio.get<dynamic>(
        '/api/v1/seasons',
        queryParameters: queryParams,
      );

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
      }
      var errorMsg = 'Failed to load seasons (Status: ${response.statusCode})';
      try {
        final errorData = response.data as Map<String, dynamic>?;
        if (errorData != null && errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
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
          // By the time this reaches the wire, `season.plantId`/`landId`
          // are already the parent's server id — the syncer's
          // `translateSeasonFks` (fk_translators.dart) resolves an unsynced
          // parent's client_uuid to its server id before push via
          // `BaseEntitySyncer.resolveFks`.
          'plant_id': int.tryParse(season.plantId) ?? 0,
          'land_id': int.tryParse(season.landId) ?? 0,
          'start_date': season.startDate.toUtc().toIso8601String(),
          'end_date': season.endDate?.toUtc().toIso8601String(),
          // Required for the offline sync path: P1's create endpoint keys
          // its idempotency check on (user_id, client_uuid) — a retried
          // push (same clientUuid) returns the ALREADY-created row instead
          // of duplicating it. Harmless for the flag-off legacy path too:
          // `SeasonModel.create` always mints a fresh clientUuid there, so
          // this is just an unused-but-valid extra field server-side.
          'client_uuid': season.clientUuid,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return SeasonModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
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
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
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
