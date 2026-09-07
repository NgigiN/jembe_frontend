import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';

abstract class LandRemoteDataSource {
  /// Fetches all lands, or — when [updatedSince] is given — only those the
  /// server has changed strictly after that instant (used by the sync
  /// pull phase). Existing no-arg callers (the flag-off repo path) are
  /// unaffected.
  ///
  /// [limit] caps the page size (server default & max is 500) and [cursor]
  /// pages backward through the newest-first list — the server returns rows
  /// with `id < cursor`. Both are used ONLY by the online infinite-scroll
  /// list path (P3-02a); the sync pull passes neither.
  Future<List<LandModel>> getLands({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  });
  Future<LandModel> addLand(LandModel land);
  Future<LandModel> updateLand(LandModel land);
  Future<void> deleteLand(String id);
}

class LandRemoteDataSourceImpl implements LandRemoteDataSource {
  LandRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<LandModel>> getLands({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (updatedSince != null)
          'updated_since': updatedSince.toUtc().toIso8601String(),
        if (limit != null) 'limit': limit,
        if (cursor != null) 'cursor': cursor,
      };

      final response = await dio.get<dynamic>(
        '/api/v1/lands',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map((json) => LandModel.fromJson(json as Map<String, dynamic>))
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
  Future<LandModel> addLand(LandModel land) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/lands',
        data: {
          'name': land.name,
          'size': land.size,
          'location': land.location,
          'soil_type': land.soilType,
          'tenure_type': land.tenureType,
          // Required for the offline sync path: P1's create endpoint keys
          // its idempotency check on (user_id, client_uuid) — a retried
          // push (same clientUuid) returns the ALREADY-created row instead
          // of duplicating it. Harmless for the flag-off legacy path too:
          // `LandModel.create` always mints a fresh clientUuid there, so
          // this is just an unused-but-valid extra field server-side.
          'client_uuid': land.clientUuid,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return LandModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<LandModel> updateLand(LandModel land) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/lands/${land.id}',
        data: {
          'name': land.name,
          'size': land.size,
          'location': land.location,
          'soil_type': land.soilType,
          'tenure_type': land.tenureType,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return LandModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteLand(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/lands/$id');

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
