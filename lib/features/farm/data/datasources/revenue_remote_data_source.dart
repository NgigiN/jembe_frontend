import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';

abstract class RevenueRemoteDataSource {
  /// Fetches revenues matching the given filters, or — when [updatedSince]
  /// is given — only those the server has changed strictly after that
  /// instant (used by the sync pull phase, which passes ONLY
  /// [updatedSince], never [source]/[startDate]/[endDate]). Existing
  /// filtered callers (the flag-off repo path) are unaffected.
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedSince,
  });
  Future<RevenueModel> getRevenueById(String id);
  Future<RevenueModel> addRevenue(RevenueModel revenue);
  Future<RevenueModel> updateRevenue(RevenueModel revenue);
  Future<void> deleteRevenue(String id);
}

class RevenueRemoteDataSourceImpl implements RevenueRemoteDataSource {
  RevenueRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedSince,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (source != null) {
        queryParams['source'] = source;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (updatedSince != null) {
        queryParams['updated_since'] = updatedSince.toUtc().toIso8601String();
      }

      final response = await dio.get<dynamic>(
        '/api/v1/revenue',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map(
                (json) => RevenueModel.fromJson(json as Map<String, dynamic>),
              )
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
  Future<RevenueModel> getRevenueById(String id) async {
    try {
      final response = await dio.get<dynamic>('/api/v1/revenue/$id');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return RevenueModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<RevenueModel> addRevenue(RevenueModel revenue) async {
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/revenue',
        data: {
          ...revenue.toJson(),
          // Required for the offline sync path: P1's create endpoint keys
          // its idempotency check on (user_id, client_uuid) — a retried
          // push (same clientUuid) returns the ALREADY-created row instead
          // of duplicating it. Harmless for the flag-off legacy path too:
          // `RevenueModel.create` always mints a fresh clientUuid there, so
          // this is just an unused-but-valid extra field server-side.
          'client_uuid': revenue.clientUuid,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return RevenueModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<RevenueModel> updateRevenue(RevenueModel revenue) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/revenue/${revenue.id}',
        data: revenue.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return RevenueModel.fromJson(data);
      }
      final msg = extractServerErrorMessage(response.data);
      throw ServerException(msg.isNotEmpty ? msg : null);
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteRevenue(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/revenue/$id');

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
