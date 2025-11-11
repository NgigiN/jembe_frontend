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
        Uri.parse('$baseUrl/api/collections/activities/records'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Activities API Response Status: ${response.statusCode}');
      print('Activities API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        print('Found ${items.length} activities');
        return items.map((json) => ActivityModel.fromJson(json)).toList();
      } else {
        String errorMsg =
            'Failed to load activities (Status: ${response.statusCode})';
        try {
          final data = json.decode(response.body);
          if (data is Map && data['data'] != null) {
            errorMsg = data['data'].toString();
          } else if (data['message'] != null) {
            errorMsg = data['message'].toString();
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
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/activities/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'season_id': activity.seasonId,
        'land_id': activity.landId,
        'type': activity.type,
        'date': activity.date.toIso8601String(),
        'cost': activity.cost,
        'details': activity.details,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ActivityModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add activity';
      try {
        final data = json.decode(response.body);
        if (data is Map && data['data'] != null) {
          errorMsg = data['data'].toString();
        } else if (data['message'] != null) {
          errorMsg = data['message'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<ActivityModel> updateActivity(ActivityModel activity) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/activities/records/${activity.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'land_id': activity.landId,
        'type': activity.type,
        'date': activity.date.toIso8601String(),
        'cost': activity.cost,
        'details': activity.details,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ActivityModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<void> deleteActivity(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/collections/activities/records/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw ServerException();
    }
  }
}
