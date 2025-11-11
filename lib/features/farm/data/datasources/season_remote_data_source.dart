import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/season_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class SeasonRemoteDataSource {
  Future<List<SeasonModel>> getSeasons();
  Future<SeasonModel> addSeason(SeasonModel season);
  Future<SeasonModel> updateSeason(SeasonModel season);
  Future<void> deleteSeason(String id);
}

class SeasonRemoteDataSourceImpl implements SeasonRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  SeasonRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<SeasonModel>> getSeasons() async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw ServerException('No authentication token found');
    }

    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/seasons'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Seasons API Response Status: ${response.statusCode}');
      print('Seasons API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        print('Found ${items.length} seasons');
        return items.map((json) => SeasonModel.fromJson(json)).toList();
      } else {
        String errorMsg =
            'Failed to load seasons (Status: ${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } catch (e) {
      print('Error in getSeasons: $e');
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException('Network error: $e');
    }
  }

  @override
  Future<SeasonModel> addSeason(SeasonModel season) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/seasons'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': season.name,
        'plant_id': season.plantId,
        'land_id': season.landId,
        'start_date': season.startDate.toIso8601String().split('T')[0],
        'end_date': season.endDate?.toIso8601String().split('T')[0],
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return SeasonModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add season';
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
  Future<SeasonModel> updateSeason(SeasonModel season) async {
    final token = await _getToken();
    final response = await client.put(
      Uri.parse('$baseUrl/api/seasons/${season.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': season.name,
        'plant_id': season.plantId,
        'land_id': season.landId,
        'start_date': season.startDate.toIso8601String().split('T')[0],
        'end_date': season.endDate?.toIso8601String().split('T')[0],
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return SeasonModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update season';
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
  Future<void> deleteSeason(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/seasons/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      String errorMsg = 'Failed to delete season';
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
