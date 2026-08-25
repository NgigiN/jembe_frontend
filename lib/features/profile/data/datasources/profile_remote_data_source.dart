import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required int fiscalYearStartMonth,
    String? farmName,
    String? location,
  });
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
  Future<void> deleteAccount();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/profile');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['profile'] != null) {
          return UserModel.fromJson(data['profile'] as Map<String, dynamic>);
        } else {
          throw const ServerException('Profile data could not be loaded. Please try again.');
        }
      } else {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in getProfile', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required int fiscalYearStartMonth,
    String? farmName,
    String? location,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/profile',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'fiscal_year_start_month': fiscalYearStartMonth,
          if (farmName != null) 'farm_name': farmName,
          if (location != null) 'location': location,
        },
      );

      if (response.statusCode != 200) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in updateProfile', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/profile/password',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );

      if (response.statusCode != 200) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in changePassword', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/profile');

      if (response.statusCode != 200 && response.statusCode != 204) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException in deleteAccount', e);
      throw mapDioException(e);
    }
  }
}
