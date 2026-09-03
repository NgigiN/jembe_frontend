import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';

abstract class ActivityRemoteDataSource {
  Future<List<ActivityModel>> getActivities({String? sourceType});
  Future<ActivityModel> addActivity(ActivityModel activity);
  Future<ActivityModel> updateActivity(ActivityModel activity);
  Future<void> deleteActivity(String id);
}

class ActivityRemoteDataSourceImpl implements ActivityRemoteDataSource {
  ActivityRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<ActivityModel>> getActivities({String? sourceType}) async {
    try {
      final queryParams = sourceType != null && sourceType.isNotEmpty
          ? {'source_type': sourceType}
          : null;

      final response = await dio.get<dynamic>(
        '/api/v1/activities',
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

        final items = data;
        appLogger.info(LogCategory.farm, 'Found ${items.length} activities');
        return items
            .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        var errorMsg =
            'Failed to load activities (Status: ${response.statusCode})';
        try {
          final errorData = response.data;
          if (errorData != null &&
              errorData is Map<String, dynamic> &&
              errorData['error'] != null) {
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
        '/api/v1/activities',
        data: requestBody,
      );

      if (response.statusCode == 201) {
        final data = response.data!;
        return ActivityModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to add activity';
        try {
          final errorData = response.data;
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
        '/api/v1/activities/${activity.id}',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        final data = response.data!;
        return ActivityModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to update activity';
        try {
          final errorData = response.data;
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
  Future<void> deleteActivity(String id) async {
    try {
      final response = await dio.delete<Map<String, dynamic>>(
        '/api/v1/activities/$id',
      );

      if (response.statusCode != 200) {
        var errorMsg = 'Failed to delete activity';
        try {
          final errorData = response.data;
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
}
