import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/herd_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class HerdRemoteDataSource {
  Future<List<HerdModel>> getHerds();
  Future<HerdModel> addHerd(HerdModel herd);
  Future<HerdModel> updateHerd(HerdModel herd);
  Future<void> deleteHerd(String id);
}

class HerdRemoteDataSourceImpl implements HerdRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  HerdRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<HerdModel>> getHerds() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/herds'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null) return [];
      return (data as List)
          .map((json) => HerdModel.fromJson(json))
          .toList();
    } else {
      String errorMsg = 'Failed to load herds';
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
  Future<HerdModel> addHerd(HerdModel herd) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/herds'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(herd.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return HerdModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add herd';
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
  Future<HerdModel> updateHerd(HerdModel herd) async {
    final token = await _getToken();
    final response = await client.put(
      Uri.parse('$baseUrl/api/herds/${herd.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(herd.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return HerdModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update herd';
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
  Future<void> deleteHerd(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/herds/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      String errorMsg = 'Failed to delete herd';
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

