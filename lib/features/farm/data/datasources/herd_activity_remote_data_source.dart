import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';

abstract class HerdActivityRemoteDataSource {
  Future<HerdActivityModel> addHerdActivity(String herdId, HerdActivityModel activity);
}

class HerdActivityRemoteDataSourceImpl implements HerdActivityRemoteDataSource {
  HerdActivityRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<HerdActivityModel> addHerdActivity(
    String herdId,
    HerdActivityModel activity,
  ) async {
    try {
      final response = await dio.post(
        '/api/v1/herds/$herdId/activities',
        data: activity.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdActivityModel.fromJson(data);
      } else {
        var errorMsg = 'Failed to record herd activity';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      var errorMsg = 'Failed to record herd activity';
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data as Map<String, dynamic>;
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
      }
      throw ServerException(errorMsg);
    }
  }
}
