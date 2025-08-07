import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/land_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class LandRemoteDataSource {
  Future<List<LandModel>> getLands();
  Future<LandModel> addLand(LandModel land);
  Future<LandModel> updateLand(LandModel land);
  Future<void> deleteLand(String id);
}

class LandRemoteDataSourceImpl implements LandRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  LandRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
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
  Future<LandModel> addLand(LandModel land) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/lands/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'user_id': land.userId,
        'name': land.name,
        'size': land.size,
        'location': land.location,
        'soil_type': land.soilType,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return LandModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add land';
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
  Future<LandModel> updateLand(LandModel land) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/lands/records/${land.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': land.name,
        'size': land.size,
        'location': land.location,
        'soil_type': land.soilType,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return LandModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<void> deleteLand(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/collections/lands/records/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw ServerException();
    }
  }
}
