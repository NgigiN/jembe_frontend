import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';

abstract class InputRemoteDataSource {
  /// Fetches inputs, optionally filtered by [sourceType] (unrelated to
  /// offline sync — an existing app-level filter), or — when [updatedSince]
  /// is given — only those the server has changed strictly after that
  /// instant (used by the sync pull phase, which passes ONLY [updatedSince],
  /// never [sourceType]). Existing callers are unaffected.
  Future<List<InputModel>> getInputs({
    String? sourceType,
    DateTime? updatedSince,
  });
  Future<InputModel> addInput(InputModel input);
  Future<InputModel> updateInput(InputModel input);
  Future<void> deleteInput(String id);
}

class InputRemoteDataSourceImpl implements InputRemoteDataSource {
  InputRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<InputModel>> getInputs({
    String? sourceType,
    DateTime? updatedSince,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (sourceType != null && sourceType.isNotEmpty)
          'source_type': sourceType,
        if (updatedSince != null)
          'updated_since': updatedSince.toUtc().toIso8601String(),
      };

      final response = await dio.get<dynamic>(
        '/api/v1/inputs',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      appLogger.debug(
        LogCategory.http,
        'Inputs API Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) {
          appLogger.info(LogCategory.farm, 'No inputs found (null response)');
          return [];
        }

        if (data is! List) {
          appLogger.warning(
            LogCategory.http,
            'Unexpected response format: expected List, got ${data.runtimeType}',
          );
          return [];
        }

        final items = data;
        appLogger.info(LogCategory.farm, 'Found ${items.length} inputs');
        return items
            .map((json) => InputModel.fromJson(json as Map<String, dynamic>))
            .toList();
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
  Future<InputModel> addInput(InputModel input) async {
    try {
      final requestBody = <String, dynamic>{
        'source_type': input.sourceType,
        'source_id': int.tryParse(input.sourceId) ?? 0,
        'type': input.type,
        'quantity': input.quantity,
        'cost': input.cost,
        'date': input.date.toUtc().toIso8601String(),
        'notes': input.notes,
      };
      if (input.animalId != null && input.animalId != 0) {
        requestBody['animal_id'] = input.animalId;
      }
      // Required for the offline sync path: P1's create endpoint keys its
      // idempotency check on (user_id, client_uuid) — a retried push (same
      // clientUuid) returns the ALREADY-created row instead of duplicating
      // it. Harmless for the flag-off legacy path too: `InputModel.create`
      // always mints a fresh clientUuid there, so this is just an
      // unused-but-valid extra field server-side.
      requestBody['client_uuid'] = input.clientUuid;

      final response = await dio.post<dynamic>('/api/v1/inputs', data: requestBody);

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return InputModel.fromJson(data);
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
  Future<InputModel> updateInput(InputModel input) async {
    try {
      final requestBody = <String, dynamic>{
        'source_type': input.sourceType,
        'source_id': int.tryParse(input.sourceId) ?? 0,
        'type': input.type,
        'quantity': input.quantity,
        'cost': input.cost,
        'date': input.date.toUtc().toIso8601String(),
        'notes': input.notes,
      };
      if (input.animalId != null && input.animalId != 0) {
        requestBody['animal_id'] = input.animalId;
      }

      final response = await dio.put<dynamic>(
        '/api/v1/inputs/${input.id}',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return InputModel.fromJson(data);
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
  Future<void> deleteInput(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/inputs/$id');

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
