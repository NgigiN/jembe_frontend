import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/logging/app_logger.dart';
import '../../../auth/data/services/user_storage_service.dart';
import '../../../../core/config/app_config.dart';

class FarmDataService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<String?> _getToken() async {
    return await UserStorageService.getToken();
  }

  static Future<List<Map<String, dynamic>>> getLandsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/lands'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        return items
            .map(
              (item) => {
                'id': (item['ID'] ?? item['id'] ?? '').toString(),
                'name': item['Name'] ?? item['name'] ?? '',
                'location': item['Location'] ?? item['location'] ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      appLogger.error(LogCategory.farm, 'Error fetching lands', e);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getPlantsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/plants'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        return items
            .map(
              (item) => {
                'id': (item['ID'] ?? item['id'] ?? '').toString(),
                'name': item['Name'] ?? item['name'] ?? '',
                'variety': item['Variety'] ?? item['variety'] ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      appLogger.error(LogCategory.farm, 'Error fetching plants', e);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSeasonsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/seasons'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        return items
            .map(
              (item) => {
                'id': (item['ID'] ?? item['id'] ?? '').toString(),
                'name': item['Name'] ?? item['name'] ?? '',
                'start_date': item['StartDate'] ?? item['start_date'],
              },
            )
            .toList();
      }
    } catch (e) {
      appLogger.error(LogCategory.farm, 'Error fetching seasons', e);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAnimalsForDropdown() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/animals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        return items
            .map(
              (item) => {
                'id': (item['ID'] ?? item['id'] ?? '').toString(),
                'name': item['Name'] ?? item['name'] ?? '',
                'type': item['Type'] ?? item['type'] ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      appLogger.error(LogCategory.farm, 'Error fetching animals', e);
    }
    return [];
  }

  static Future<http.Response> getTotalCosts({
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available. Please log in.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/analytics/total-costs').replace(
        queryParameters: {
          if (type != null) 'type': type,
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
        },
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      return response;
    } catch (e) {
      appLogger.error(LogCategory.http, 'Error in getTotalCosts', e);
      rethrow;
    }
  }

  static Future<http.Response> getCostBreakdown({
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available. Please log in.');
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/analytics/cost-breakdown').replace(
        queryParameters: {
          if (type != null) 'type': type,
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
        },
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      return response;
    } catch (e) {
      appLogger.error(LogCategory.http, 'Error in getCostBreakdown', e);
      rethrow;
    }
  }

  static Future<http.Response> getMonthlySummary({required int year}) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available. Please log in.');
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/api/v1/analytics/monthly-summary',
      ).replace(queryParameters: {'year': year.toString()});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      return response;
    } catch (e) {
      appLogger.error(LogCategory.http, 'Error in getMonthlySummary', e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getCostCategories({
    String? type,
    String? category,
  }) async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;
      if (category != null) queryParams['category'] = category;

      final uri = Uri.parse(
        '$baseUrl/api/v1/cost-categories',
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data as List;
        return items
            .map(
              (item) => {
                'id': (item['id'] ?? item['ID'] ?? '').toString(),
                'name': item['name'] ?? item['Name'] ?? '',
                'type': item['type'] ?? item['Type'] ?? '',
                'category': item['category'] ?? item['Category'] ?? '',
                'is_default': item['is_default'] ?? item['isDefault'] ?? false,
              },
            )
            .toList();
      }
    } catch (e) {
      appLogger.error(LogCategory.farm, 'Error fetching cost categories', e);
    }
    return [];
  }

  static Future<bool> createCostCategory({
    required String name,
    required String type,
    required String category,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token available. Please log in.');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/cost-categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': name, 'type': type, 'category': category}),
      );

      return response.statusCode == 201;
    } catch (e) {
      appLogger.error(LogCategory.farm, 'Error creating cost category', e);
      return false;
    }
  }
}
