import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
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
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }
}
