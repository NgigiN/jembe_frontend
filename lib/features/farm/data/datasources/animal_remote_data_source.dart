import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/animal_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class AnimalRemoteDataSource {
  Future<List<AnimalModel>> getAnimals();
  Future<AnimalModel> addAnimal(AnimalModel animal);
  Future<AnimalModel> updateAnimal(AnimalModel animal);
  Future<void> deleteAnimal(String id);
}

class AnimalRemoteDataSourceImpl implements AnimalRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  AnimalRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<AnimalModel>> getAnimals() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/animals'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data as List)
          .map((json) => AnimalModel.fromJson(json))
          .toList();
    } else {
      String errorMsg = 'Failed to load animals';
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
  Future<AnimalModel> addAnimal(AnimalModel animal) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/animals'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': animal.name,
        'type': animal.type,
        'number': animal.number,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return AnimalModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add animal';
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
  Future<AnimalModel> updateAnimal(AnimalModel animal) async {
    final token = await _getToken();
    final response = await client.put(
      Uri.parse('$baseUrl/api/animals/${animal.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': animal.name,
        'type': animal.type,
        'number': animal.number,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AnimalModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update animal';
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
  Future<void> deleteAnimal(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/animals/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      String errorMsg = 'Failed to delete animal';
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

