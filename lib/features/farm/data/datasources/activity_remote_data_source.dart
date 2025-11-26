import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/activity_model.dart';

abstract class ActivityRemoteDataSource {
  Future<List<ActivityModel>> getActivities({String? sourceType});
  Future<ActivityModel> addActivity(ActivityModel activity);
  Future<ActivityModel> updateActivity(ActivityModel activity);
  Future<void> deleteActivity(String id);
}

class ActivityRemoteDataSourceImpl implements ActivityRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  ActivityRemoteDataSourceImpl({required this.dio, required this.baseUrl});

  @override
  Future<List<ActivityModel>> getActivities({String? sourceType}) async {
    try {
      final queryParams = sourceType != null && sourceType.isNotEmpty
          ? {'source_type': sourceType}
          : null;

      final response = await dio.get<Map<String, dynamic>>(
        '/api/activities',
        queryParameters: queryParams,
      );

      appLogger.debug(
        LogCategory.http,
        'Activities API Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) {
          appLogger.info(LogCategory.farm, 'No activities found (null)');
          return [];
        }

        if (data is! List) {
          appLogger.warning(
            LogCategory.http,
            'Unexpected response: expected List, got ${data.runtimeType}',
          );
          return [];
        }

        final items = data as List;
        appLogger.info(LogCategory.farm, 'Found ${items.length} activities');
        return items
            .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        String errorMsg =
            'Failed to load activities (Status: ${response.statusCode})';
        try {
          final errorData = response.data;
          if (errorData != null && errorData is Map<String, dynamic> && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'Error in getActivities', e);
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
  Future<ActivityModel> addActivity(ActivityModel activity) async {
    try {
      final requestBody = <String, dynamic>{
        'source_type': activity.sourceType,
        'source_id': int.tryParse(activity.sourceId) ?? 0,
        'type': activity.type,
        'details': activity.details,
        'cost': activity.cost,
        'date': activity.date.toUtc().toIso8601String(),
        'notes': activity.notes,
      };
      if (activity.animalId != null && activity.animalId != 0) {
        requestBody['animal_id'] = activity.animalId;
      }

      final response = await dio.post<Map<String, dynamic>>(
        '/api/activities',
        data: requestBody,
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return ActivityModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to add activity';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to add activity';
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
  Future<ActivityModel> updateActivity(ActivityModel activity) async {
    try {
      final requestBody = <String, dynamic>{
        'source_type': activity.sourceType,
        'source_id': int.tryParse(activity.sourceId) ?? 0,
        'type': activity.type,
        'details': activity.details,
        'cost': activity.cost,
        'date': activity.date.toUtc().toIso8601String(),
        'notes': activity.notes,
      };
      if (activity.animalId != null && activity.animalId != 0) {
        requestBody['animal_id'] = activity.animalId;
      }

      final response = await dio.put<Map<String, dynamic>>(
        '/api/activities/${activity.id}',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return ActivityModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to update activity';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to update activity';
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
  Future<void> deleteActivity(String id) async {
    try {
      final response = await dio.delete<Map<String, dynamic>>('/api/activities/$id');

      if (response.statusCode != 200) {
        String errorMsg = 'Failed to delete activity';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to delete activity';
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
