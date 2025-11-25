import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/exceptions.dart';
import '../models/land_model.dart';
import '../models/plant_model.dart';
import '../models/season_model.dart';
import '../models/activity_model.dart';

abstract class FarmRemoteDataSource {
  Future<List<LandModel>> getLands();
  Future<LandModel> addLand(String name);
  Future<LandModel> updateLand(String id, String name);
  Future<List<PlantModel>> getPlants();
  Future<PlantModel> addPlant(String name);
  Future<PlantModel> updatePlant(String id, String name);
  Future<List<SeasonModel>> getSeasons();
  Future<SeasonModel> addSeason(String name);
  Future<SeasonModel> updateSeason(String id, String name);
  Future<List<ActivityModel>> getActivities();
  Future<ActivityModel> addActivity(String description);
}

class FarmRemoteDataSourceImpl implements FarmRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  FarmRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  @override
  Future<List<LandModel>> getLands() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/collections/lands/records'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['items'] as List)
          .map((json) => LandModel.fromJson(json))
          .toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<LandModel> addLand(String name) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/lands/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return LandModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<LandModel> updateLand(String id, String name) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/lands/records/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return LandModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<List<PlantModel>> getPlants() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/collections/crops/records'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['items'] as List)
          .map((json) => PlantModel.fromJson(json))
          .toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<PlantModel> addPlant(String name) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/crops/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return PlantModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<PlantModel> updatePlant(String id, String name) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/crops/records/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return PlantModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<List<SeasonModel>> getSeasons() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/collections/seasons/records'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['items'] as List)
          .map((json) => SeasonModel.fromJson(json))
          .toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<SeasonModel> addSeason(String name) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/seasons/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return SeasonModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<SeasonModel> updateSeason(String id, String name) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/seasons/records/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': name}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return SeasonModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<List<ActivityModel>> getActivities() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/collections/activities/records'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['items'] as List)
          .map((json) => ActivityModel.fromJson(json))
          .toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<ActivityModel> addActivity(String description) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/activities/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'description': description}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ActivityModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }
}
