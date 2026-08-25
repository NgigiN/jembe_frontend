import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';

abstract class HerdRemoteDataSource {
  Future<List<HerdModel>> getHerds();
  Future<HerdModel> addHerd(HerdModel herd);
  Future<HerdModel> updateHerd(HerdModel herd);
  Future<void> deleteHerd(String id);
}

class HerdRemoteDataSourceImpl implements HerdRemoteDataSource {
  HerdRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<HerdModel>> getHerds() async {
    try {
      final response = await dio.get<dynamic>('/api/v1/herds');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map((json) => HerdModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<HerdModel> addHerd(HerdModel herd) async {
    try {
      final response = await dio.post<dynamic>('/api/v1/herds', data: herd.toJson());

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdModel.fromJson(data);
      } else {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<HerdModel> updateHerd(HerdModel herd) async {
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/herds/${herd.id}',
        data: herd.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return HerdModel.fromJson(data);
      } else {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }

  @override
  Future<void> deleteHerd(String id) async {
    try {
      final response = await dio.delete<dynamic>('/api/v1/herds/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        final msg = extractServerErrorMessage(response.data);
        throw ServerException(msg.isNotEmpty ? msg : null);
      }
    } on DioException catch (e) {
      appLogger.error(LogCategory.http, 'DioException', e);
      throw mapDioException(e);
    }
  }
}
