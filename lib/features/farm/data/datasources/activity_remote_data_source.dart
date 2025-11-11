import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/activity_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class ActivityRemoteDataSource {
  Future<List<ActivityModel>> getActivities();
  Future<ActivityModel> addActivity(ActivityModel activity);
  Future<ActivityModel> updateActivity(ActivityModel activity);
  Future<void> deleteActivity(String id);
}

class ActivityRemoteDataSourceImpl implements ActivityRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  ActivityRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<ActivityModel>> getActivities() async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw ServerException('No authentication token found');
    }

    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/activities'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Activities API Response Status: ${response.statusCode}');
      print('Activities API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        print('Found ${items.length} activities');
        return items.map((json) => ActivityModel.fromJson(json)).toList();
      } else {
        String errorMsg =
            'Failed to load activities (Status: ${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } catch (e) {
      print('Error in getActivities: $e');
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException('Network error: $e');
    }
  }

  @override
  Future<ActivityModel> addActivity(ActivityModel activity) async {
    final token = await _getToken();
    final requestBody = {
      'source_type': activity.sourceType,
      'source_id': activity.sourceId,
      'type': activity.type,
      'details': activity.details,
      'cost': activity.cost,
      'date': activity.date.toIso8601String().split('T')[0],
      'notes': activity.notes,
    };
    if (activity.animalId != null && activity.animalId != 0) {
      requestBody['animal_id'] = activity.animalId;
    }

    final response = await client.post(
      Uri.parse('$baseUrl/api/activities'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return ActivityModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add activity';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<ActivityModel> updateActivity(ActivityModel activity) async {
    final token = await _getToken();
    final requestBody = {
      'source_type': activity.sourceType,
      'source_id': activity.sourceId,
      'type': activity.type,
      'details': activity.details,
      'cost': activity.cost,
      'date': activity.date.toIso8601String().split('T')[0],
      'notes': activity.notes,
    };
    if (activity.animalId != null && activity.animalId != 0) {
      requestBody['animal_id'] = activity.animalId;
    }

    final response = await client.put(
      Uri.parse('$baseUrl/api/activities/${activity.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ActivityModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update activity';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<void> deleteActivity(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/activities/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      String errorMsg = 'Failed to delete activity';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
    }
  }
}
