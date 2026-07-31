import 'package:dio/dio.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';

abstract class HarvestRemoteDataSource {
  Future<List<HarvestModel>> getHarvests({String? seasonId});
  Future<HarvestModel> addHarvest(HarvestModel harvest);
  Future<HarvestModel> updateHarvest(HarvestModel harvest);
  Future<void> deleteHarvest(String id);
}

class HarvestRemoteDataSourceImpl implements HarvestRemoteDataSource {
  HarvestRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<List<HarvestModel>> getHarvests({String? seasonId}) async {
    try {
      final queryParams = seasonId != null && seasonId.isNotEmpty
          ? {'season_id': seasonId}
          : null;

      final response = await dio.get(
        '/api/v1/harvests',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null || data is! List) {
          return [];
        }
        return data
            .map((json) => HarvestModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw const ServerException('Failed to load harvests');
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Failed to load harvests');
    }
  }

  @override
  Future<HarvestModel> addHarvest(HarvestModel harvest) async {
    try {
      final response = await dio.post(
        '/api/v1/harvests',
        data: harvest.toJson(),
      );

      if (response.statusCode == 201) {
        return HarvestModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerException('Failed to add harvest');
    } on DioException catch (e) {
      throw ServerException(_extractError(e, 'Failed to add harvest'));
    }
  }

  @override
  Future<HarvestModel> updateHarvest(HarvestModel harvest) async {
    try {
      final response = await dio.put(
        '/api/v1/harvests/${harvest.id}',
        data: harvest.toJson(),
      );

      if (response.statusCode == 200) {
        return HarvestModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerException('Failed to update harvest');
    } on DioException catch (e) {
      throw ServerException(_extractError(e, 'Failed to update harvest'));
    }
  }

  @override
  Future<void> deleteHarvest(String id) async {
    try {
      final response = await dio.delete('/api/v1/harvests/$id');
      if (response.statusCode != 200) {
        throw const ServerException('Failed to delete harvest');
      }
    } on DioException catch (e) {
      throw ServerException(_extractError(e, 'Failed to delete harvest'));
    }
  }

  String _extractError(DioException e, String fallback) {
    if (e.response?.data != null) {
      try {
        final errorData = e.response!.data as Map<String, dynamic>;
        if (errorData['error'] != null) {
          return errorData['error'].toString();
        }
      } catch (_) {}
    }
    return fallback;
  }
}