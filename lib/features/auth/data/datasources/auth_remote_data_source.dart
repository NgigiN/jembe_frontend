import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String email, String password);
  Future<UserModel> signup(
    String email,
    String password,
    String name,
    String farmName,
    String location,
  );
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  AuthRemoteDataSourceImpl({required this.client, required this.baseUrl});

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/users/auth-with-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identity': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'user': UserModel.fromJson(data['record']),
        'token': data['token'],
        'record': data['record'],
      };
    } else {
      throw ServerException();
    }
  }

  @override
  Future<UserModel> signup(
    String email,
    String password,
    String name,
    String farmName,
    String location,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/collections/users/records'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
        'farm_name': farmName,
        'location': location,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return UserModel.fromJson(data);
    } else {
      String errorMsg = 'Signup failed';
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
}
