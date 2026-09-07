import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';

abstract class HerdRemoteDataSource {
  /// Fetches all herds, or — when [updatedSince] is given — only those the
  /// server has changed strictly after that instant (used by the sync pull
  /// phase). Existing no-arg callers (the flag-off repo path) are
  /// unaffected.
  ///
  /// [limit] caps the page size (server default & max is 500) and [cursor]
  /// pages backward through the newest-first list — the server returns rows
  /// with `id < cursor`. Both are used ONLY by the online infinite-scroll
  /// list path (P3-02a); the sync pull passes neither.
  Future<List<HerdModel>> getHerds({
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  });
  Future<HerdModel> addHerd(HerdModel herd);
  Future<HerdModel> updateHerd(HerdModel herd);
  Future<void> deleteHerd(String id);
}

class HerdRemoteDataSourceImpl implements HerdRemoteDataSource {
  HerdRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<HerdModel>> getHerds({
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
        '/api/v1/herds',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map((json) => HerdModel.fromJson(json as Map<String, dynamic>))
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
  Future<HerdModel> addHerd(HerdModel herd) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/herds',
        data: {
          ...herd.toJson(),
          // Required for the offline sync path: P1's create endpoint keys
          // its idempotency check on (user_id, client_uuid) — a retried
          // push (same clientUuid) returns the ALREADY-created row instead
          // of duplicating it. Harmless for the flag-off legacy path too:
          // `HerdModel.create` always mints a fresh clientUuid there, so
          // this is just an unused-but-valid extra field server-side.
          'client_uuid': herd.clientUuid,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<HerdModel> updateHerd(HerdModel herd) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/herds/${herd.id}',
        data: herd.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteHerd(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/herds/$id');

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
