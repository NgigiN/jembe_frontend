import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? farmName,
    String? location,
  });
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await dio.get('/api/v1/profile');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['profile'] != null) {
          return UserModel.fromJson(data['profile'] as Map<String, dynamic>);
        } else {
          throw const ServerException('Invalid response format');
        }
      } else {
        throw ServerException(
          _extractErrorMessage(response.data) ?? 'Failed to get profile',
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        _extractErrorMessage(e.response?.data) ?? 'Failed to get profile',
      );
    }
  }

  @override
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    String? farmName,
    String? location,
  }) async {
    try {
      final response = await dio.put(
        '/api/v1/profile',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          if (farmName != null) 'farm_name': farmName,
          if (location != null) 'location': location,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          _extractErrorMessage(response.data) ?? 'Failed to update profile',
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        _extractErrorMessage(e.response?.data) ?? 'Failed to update profile',
      );
    }
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await dio.put(
        '/api/v1/profile/password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );

      if (response.statusCode != 200) {
        throw ServerException(
          _extractErrorMessage(response.data) ?? 'Failed to change password',
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        _extractErrorMessage(e.response?.data) ?? 'Failed to change password',
      );
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['error'] != null) return data['error'].toString();
      if (data['message'] != null) return data['message'].toString();
    }
    return null;
  }
}
