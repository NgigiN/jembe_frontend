import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/animal_type_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class AnimalTypeRemoteDataSource {
  Future<List<AnimalTypeModel>> getAnimalTypes();
  Future<AnimalTypeModel> getAnimalType(String id);
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType);
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType);
  Future<void> deleteAnimalType(String id);
}

class AnimalTypeRemoteDataSourceImpl implements AnimalTypeRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  AnimalTypeRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<AnimalTypeModel>> getAnimalTypes() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/animal-types'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null) return [];
      return (data as List)
          .map((json) => AnimalTypeModel.fromJson(json))
          .toList();
    } else {
      String errorMsg = 'Failed to load animal types';
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
  Future<AnimalTypeModel> getAnimalType(String id) async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/animal-types/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AnimalTypeModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to load animal type';
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
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/animal-types'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(animalType.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return AnimalTypeModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add animal type';
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
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType) async {
    final token = await _getToken();
    final response = await client.put(
      Uri.parse('$baseUrl/api/animal-types/${animalType.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(animalType.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return AnimalTypeModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update animal type';
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
  Future<void> deleteAnimalType(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/animal-types/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      String errorMsg = 'Failed to delete animal type';
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

