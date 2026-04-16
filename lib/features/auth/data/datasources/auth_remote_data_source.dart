import 'package:dio/dio.dart';
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
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = (data['token'] ?? '').toString();

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
          final errorData = response.data;
          if (errorData != null && errorData is Map<String, dynamic>) {
            if (errorData['error'] != null) {
              errorMsg = errorData['error'].toString();
            } else if (errorData['message'] != null) {
              errorMsg = errorData['message'].toString();
            }
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Login failed';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}
      }
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
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'farm_name': farmName,
          'location': location,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        if (data['user'] != null) {
          return UserModel.fromJson(data['user'] as Map<String, dynamic>);
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
          final errorData = response.data;
          if (errorData != null && errorData is Map<String, dynamic>) {
            if (errorData['error'] != null) {
              errorMsg = errorData['error'].toString();
            } else if (errorData['message'] != null) {
              errorMsg = errorData['message'].toString();
            }
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Signup failed';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }
}
