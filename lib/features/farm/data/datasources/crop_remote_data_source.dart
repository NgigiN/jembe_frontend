import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/crop_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class CropRemoteDataSource {
  Future<List<CropModel>> getCrops();
  Future<CropModel> addCrop(CropModel crop);
  Future<CropModel> updateCrop(CropModel crop);
  Future<void> deleteCrop(String id);
}

class CropRemoteDataSourceImpl implements CropRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  CropRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<CropModel>> getCrops() async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/collections/crops/records'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['items'] as List)
          .map((json) => CropModel.fromJson(json))
          .toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<CropModel> addCrop(CropModel crop) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/crops/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'user_id': crop.userId,
        'name': crop.name,
        'variety': crop.variety,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return CropModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add crop';
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
  Future<CropModel> updateCrop(CropModel crop) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/crops/records/${crop.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'name': crop.name, 'variety': crop.variety}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return CropModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<void> deleteCrop(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/collections/crops/records/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw ServerException();
    }
  }
}
