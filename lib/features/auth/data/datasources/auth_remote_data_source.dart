import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
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
        final data = Map<String, dynamic>.from(response.data! as Map);
        final token = (data['token'] ?? '').toString();

        if (data['user'] != null) {
          final userData = Map<String, dynamic>.from(data['user'] as Map);
          return {
            'user': UserModel.fromJson(userData),
            'token': token,
            'record': userData,
          };
        } else {
          return {
            'user': UserModel.empty(),
            'token': token,
            'record': <String, dynamic>{},
          };
        }
      } else {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(
        LogCategory.http,
        'Google auth request failed: ${e.requestOptions.uri} (${e.type.name})',
        e,
      );
      throw mapDioException(e);
    }
  }
}
