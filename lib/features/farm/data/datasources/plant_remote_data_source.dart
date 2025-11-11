import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/plant_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class PlantRemoteDataSource {
  Future<List<PlantModel>> getPlants();
  Future<PlantModel> addPlant(PlantModel plant);
  Future<PlantModel> updatePlant(PlantModel plant);
  Future<void> deletePlant(String id);
}

class PlantRemoteDataSourceImpl implements PlantRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  PlantRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<PlantModel>> getPlants() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/plants'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data as List)
          .map((json) => PlantModel.fromJson(json))
          .toList();
    } else {
      String errorMsg = 'Failed to load plants';
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
  Future<PlantModel> addPlant(PlantModel plant) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/plants'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': plant.name,
        'variety': plant.variety,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return PlantModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add plant';
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
  Future<PlantModel> updatePlant(PlantModel plant) async {
    final token = await _getToken();
    final response = await client.put(
      Uri.parse('$baseUrl/api/plants/${plant.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': plant.name, 'variety': plant.variety}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return PlantModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update plant';
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
  Future<void> deletePlant(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/plants/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      String errorMsg = 'Failed to delete plant';
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

