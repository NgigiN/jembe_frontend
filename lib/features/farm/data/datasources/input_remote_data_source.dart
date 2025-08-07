import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/input_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class InputRemoteDataSource {
  Future<List<InputModel>> getInputs();
  Future<InputModel> addInput(InputModel input);
  Future<InputModel> updateInput(InputModel input);
  Future<void> deleteInput(String id);
}

class InputRemoteDataSourceImpl implements InputRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  InputRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<InputModel>> getInputs() async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw ServerException('No authentication token found');
    }

    try {
      final response = await client.get(
        Uri.parse('$baseUrl/api/collections/inputs/records'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Inputs API Response Status: ${response.statusCode}');
      print('Inputs API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        print('Found ${items.length} inputs');
        return items.map((json) => InputModel.fromJson(json)).toList();
      } else {
        String errorMsg =
            'Failed to load inputs (Status: ${response.statusCode})';
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
      print('Error in getInputs: $e');
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException('Network error: $e');
    }
  }

  @override
  Future<InputModel> addInput(InputModel input) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/inputs/records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'season_id': input.seasonId,
        'type': input.type,
        'quantity': input.quantity,
        'cost': input.cost,
        'date': input.date.toIso8601String(),
        'notes': input.notes,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return InputModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add input';
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
  Future<InputModel> updateInput(InputModel input) async {
    final token = await _getToken();
    final response = await client.patch(
      Uri.parse('$baseUrl/api/collections/inputs/records/${input.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'type': input.type,
        'quantity': input.quantity,
        'cost': input.cost,
        'date': input.date.toIso8601String(),
        'notes': input.notes,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return InputModel.fromJson(data);
    } else {
      throw ServerException();
    }
  }

  @override
  Future<void> deleteInput(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/collections/inputs/records/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw ServerException();
    }
  }
}
