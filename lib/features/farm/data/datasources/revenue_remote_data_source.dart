import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/revenue_model.dart';
import '../../../auth/data/services/user_storage_service.dart';

abstract class RevenueRemoteDataSource {
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<RevenueModel> getRevenueById(String id);
  Future<RevenueModel> addRevenue(RevenueModel revenue);
  Future<RevenueModel> updateRevenue(RevenueModel revenue);
  Future<void> deleteRevenue(String id);
}

class RevenueRemoteDataSourceImpl implements RevenueRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  RevenueRemoteDataSourceImpl({required this.client, required this.baseUrl});

  Future<String> _getToken() async {
    return await UserStorageService.getToken() ?? '';
  }

  @override
  Future<List<RevenueModel>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();

    var url = '$baseUrl/api/revenue';
    final queryParams = <String>[];

    if (source != null) {
      queryParams.add('source=$source');
    }
    if (startDate != null) {
      queryParams.add(
        'start_date=${startDate.toIso8601String().split('T')[0]}',
      );
    }
    if (endDate != null) {
      queryParams.add('end_date=${endDate.toIso8601String().split('T')[0]}');
    }

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data == null) return [];
      return (data as List).map((json) => RevenueModel.fromJson(json)).toList();
    } else {
      String errorMsg = 'Failed to load revenues';
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
  Future<RevenueModel> getRevenueById(String id) async {
    final token = await _getToken();
    final response = await client.get(
      Uri.parse('$baseUrl/api/revenue/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return RevenueModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to load revenue';
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
  Future<RevenueModel> addRevenue(RevenueModel revenue) async {
    final token = await _getToken();
    final response = await client.post(
      Uri.parse('$baseUrl/api/revenue'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(revenue.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = json.decode(response.body);
      return RevenueModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to add revenue';
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
  Future<RevenueModel> updateRevenue(RevenueModel revenue) async {
    final token = await _getToken();
    final response = await client.put(
      Uri.parse('$baseUrl/api/revenue/${revenue.id}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(revenue.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return RevenueModel.fromJson(data);
    } else {
      String errorMsg = 'Failed to update revenue';
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
  Future<void> deleteRevenue(String id) async {
    final token = await _getToken();
    final response = await client.delete(
      Uri.parse('$baseUrl/api/revenue/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      String errorMsg = 'Failed to delete revenue';
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
