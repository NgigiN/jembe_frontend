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
        Uri.parse('$baseUrl/api/inputs'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print('Inputs API Response Status: ${response.statusCode}');
      print('Inputs API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        print('Found ${items.length} inputs');
        return items.map((json) => InputModel.fromJson(json)).toList();
      } else {
        String errorMsg =
            'Failed to load inputs (Status: ${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
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
    final requestBody = {
      'source_type': input.sourceType,
      'source_id': int.tryParse(input.sourceId) ?? 0,
      'type': input.type,
      'quantity': input.quantity,
      'cost': input.cost,
      'date': input.date.toUtc().toIso8601String(),
      'notes': input.notes,
    };
    if (input.animalId != null && input.animalId != 0) {
      requestBody['animal_id'] = input.animalId;
    }

    final response = await client.post(
      Uri.parse('$baseUrl/api/inputs'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return InputModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add input';
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
  Future<InputModel> updateInput(InputModel input) async {
    final token = await _getToken();
    final requestBody = {
      'source_type': input.sourceType,
      'source_id': int.tryParse(input.sourceId) ?? 0,
      'type': input.type,
      'quantity': input.quantity,
      'cost': input.cost,
      'date': input.date.toUtc().toIso8601String(),
      'notes': input.notes,
    };
    if (input.animalId != null && input.animalId != 0) {
      requestBody['animal_id'] = input.animalId;
    }

    final response = await client.put(
      Uri.parse('$baseUrl/api/inputs/${input.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return InputModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update input';
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
  Future<void> deleteInput(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/inputs/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      String errorMsg = 'Failed to delete input';
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
