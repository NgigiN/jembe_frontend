import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';

abstract class HarvestRemoteDataSource {
  /// Fetches harvests, optionally filtered by [seasonId] (unrelated to
  /// offline sync — an existing app-level filter), or — when [updatedSince]
  /// is given — only those the server has changed strictly after that
  /// instant (used by the sync pull phase, which passes ONLY [updatedSince],
  /// never [seasonId]). Existing callers are unaffected.
  Future<List<HarvestModel>> getHarvests({
    String? seasonId,
    DateTime? updatedSince,
  });
  Future<HarvestModel> addHarvest(HarvestModel harvest);
  Future<HarvestModel> updateHarvest(HarvestModel harvest);
  Future<void> deleteHarvest(String id);
}

class HarvestRemoteDataSourceImpl implements HarvestRemoteDataSource {
  HarvestRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<HarvestModel>> getHarvests({
    String? seasonId,
    DateTime? updatedSince,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (seasonId != null && seasonId.isNotEmpty) 'season_id': seasonId,
        if (updatedSince != null)
          'updated_since': updatedSince.toUtc().toIso8601String(),
      };

      final response = await dio.get<dynamic>(
        '/api/v1/harvests',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null || data is! List) {
          return [];
        }
        return data
            .map((json) => HarvestModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw const ServerException('Failed to load harvests');
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Failed to load harvests');
    }
  }

  @override
  Future<HarvestModel> addHarvest(HarvestModel harvest) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/harvests',
        data: {
          ...harvest.toJson(),
          // Required for the offline sync path: P1's create endpoint keys
          // its idempotency check on (user_id, client_uuid) — a retried
          // push (same clientUuid) returns the ALREADY-created row instead
          // of duplicating it. Harmless for the flag-off legacy path too:
          // `HarvestModel.create` always mints a fresh clientUuid there, so
          // this is just an unused-but-valid extra field server-side.
          'client_uuid': harvest.clientUuid,
        },
      );

      if (response.statusCode == 201) {
        return HarvestModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerException('Failed to add harvest');
    } on DioException catch (e) {
      throw ServerException(_extractError(e, 'Failed to add harvest'));
    }
  }

  @override
  Future<HarvestModel> updateHarvest(HarvestModel harvest) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/harvests/${harvest.id}',
        data: harvest.toJson(),
      );

      if (response.statusCode == 200) {
        return HarvestModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerException('Failed to update harvest');
    } on DioException catch (e) {
      throw ServerException(_extractError(e, 'Failed to update harvest'));
    }
  }

  @override
  Future<void> deleteHarvest(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/harvests/$id');
      if (response.statusCode != 200) {
        throw const ServerException('Failed to delete harvest');
      }
    } on DioException catch (e) {
      throw ServerException(_extractError(e, 'Failed to delete harvest'));
    }
  }

  String _extractError(DioException e, String fallback) {
    if (e.response?.data != null) {
      try {
        final errorData = e.response!.data as Map<String, dynamic>;
        if (errorData['error'] != null) {
          return errorData['error'].toString();
        }
      } catch (_) {}
    }
    return fallback;
  }
}