import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> googleSignIn(String idToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/auth/google',
        data: {'id_token': idToken},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data! as Map<String, dynamic>;
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
              email: '',
              firstName: '',
              lastName: '',
              farmName: '',
              location: '',
              pictureUrl: '',
            ),
            'token': token,
            'record': {},
          };
        }
      } else {
        var errorMsg = 'Google Sign-In failed';
        try {
          final errorData = response.data;
          if (errorData != null) {
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
      var errorMsg = 'Google Sign-In failed';
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
