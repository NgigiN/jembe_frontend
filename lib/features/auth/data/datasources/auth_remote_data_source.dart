import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login(String email, String password);
  Future<UserModel> signup(
    String email,
    String password,
    String firstName,
    String lastName,
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
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'] as String;

      if (data['user'] != null) {
        final userData = data['user'] as Map<String, dynamic>;
        return {
          'user': UserModel.fromJson(userData),
          'token': token,
          'record': userData,
        };
      } else {
        return {
          'user': UserModel(
            id: '',
            email: email,
            firstName: '',
            lastName: '',
            farmName: '',
            location: '',
          ),
          'token': token,
          'record': {'email': email},
        };
      }
    } else {
      String errorMsg = 'Login failed';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        } else if (errorData['message'] != null) {
          errorMsg = errorData['message'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
    }
  }

  @override
  Future<UserModel> signup(
    String email,
    String password,
    String firstName,
    String lastName,
    String farmName,
    String location,
  ) async {
    final response = await client.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'farm_name': farmName,
        'location': location,
      }),
    );
    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      if (data['user'] != null) {
        return UserModel.fromJson(data['user']);
      } else {
        return UserModel(
          id: '',
          email: email,
          firstName: firstName,
          lastName: lastName,
          farmName: farmName,
          location: location,
        );
      }
    } else {
      String errorMsg = 'Signup failed';
      try {
        final errorData = json.decode(response.body);
        if (errorData is Map && errorData['error'] != null) {
          errorMsg = errorData['error'].toString();
        } else if (errorData['message'] != null) {
          errorMsg = errorData['message'].toString();
        }
      } catch (_) {}
      throw ServerException(errorMsg);
    }
  }
}
