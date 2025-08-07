import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../auth/data/services/user_storage_service.dart';

class FarmDataService {
  static const String baseUrl = 'http://127.0.0.1:8090';

  static Future<String?> _getToken() async {
    return await UserStorageService.getToken();
  }

  static Future<List<Map<String, dynamic>>> getLandsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/lands/records'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items
            .map(
              (item) => {
                'id': item['id'],
                'name': item['name'],
                'location': item['location'] ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      print('Error fetching lands: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getCropsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/crops/records'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items
            .map(
              (item) => {
                'id': item['id'],
                'name': item['name'],
                'variety': item['variety'] ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      print('Error fetching crops: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSeasonsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/seasons/records'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        return items
            .map(
              (item) => {
                'id': item['id'],
                'name': item['name'],
                'start_date': item['start_date'],
              },
            )
            .toList();
      }
    } catch (e) {
      print('Error fetching seasons: $e');
    }
    return [];
  }

  // Analysis methods
  static Future<http.Response> getTotalCostsBySeason() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/collections/total_costs_by_season/records'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return response;
  }

  static Future<http.Response> getCostBreakdownByInputType() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available');
    }

    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/collections/cost_breakdown_by_input_type/records',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    return response;
  }

  static Future<http.Response> getAnnualCostSummary() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/collections/annual_cost_summary/records'),
      headers: {'Authorization': 'Bearer $token'},
    );

    return response;
  }
}
