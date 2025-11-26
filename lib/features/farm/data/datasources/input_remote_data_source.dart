import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/input_model.dart';

abstract class InputRemoteDataSource {
  Future<List<InputModel>> getInputs({String? sourceType});
  Future<InputModel> addInput(InputModel input);
  Future<InputModel> updateInput(InputModel input);
  Future<void> deleteInput(String id);
}

class InputRemoteDataSourceImpl implements InputRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  InputRemoteDataSourceImpl({required this.dio, required this.baseUrl});

  @override
  Future<List<InputModel>> getInputs({String? sourceType}) async {
    try {
      final queryParams = sourceType != null && sourceType.isNotEmpty
          ? {'source_type': sourceType}
          : null;

      final response = await dio.get(
        '/api/inputs',
        queryParameters: queryParams,
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

        final items = data as List;
        appLogger.info(LogCategory.farm, 'Found ${items.length} inputs');
        return items
            .map((json) => InputModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        String errorMsg =
            'Failed to load inputs (Status: ${response.statusCode})';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'Error in getInputs', e);
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

      final response = await dio.post(
        '/api/inputs',
        data: requestBody,
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return InputModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to add input';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to add input';
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

      final response = await dio.put(
        '/api/inputs/${input.id}',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return InputModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to update input';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to update input';
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
  Future<void> deleteInput(String id) async {
    try {
      final response = await dio.delete('/api/inputs/$id');

      if (response.statusCode != 200) {
        String errorMsg = 'Failed to delete input';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to delete input';
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
