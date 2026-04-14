import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/plant_model.dart';

abstract class PlantRemoteDataSource {
  Future<List<PlantModel>> getPlants();
  Future<PlantModel> addPlant(PlantModel plant);
  Future<PlantModel> updatePlant(PlantModel plant);
  Future<void> deletePlant(String id);
}

class PlantRemoteDataSourceImpl implements PlantRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  PlantRemoteDataSourceImpl({required this.dio, required this.baseUrl});

  @override
  Future<List<PlantModel>> getPlants() async {
    try {
      final response = await dio.get('/api/v1/plants');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .map((json) => PlantModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        String errorMsg = 'Failed to load plants';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to load plants';
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

  @override
  Future<PlantModel> addPlant(PlantModel plant) async {
    try {
      final response = await dio.post(
        '/api/v1/plants',
        data: {
          'name': plant.name,
          'variety': plant.variety,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to add plant';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to add plant';
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

  @override
  Future<PlantModel> updatePlant(PlantModel plant) async {
    try {
      final response = await dio.put(
        '/api/v1/plants/${plant.id}',
        data: {'name': plant.name, 'variety': plant.variety},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to update plant';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to update plant';
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

  @override
  Future<void> deletePlant(String id) async {
    try {
      final response = await dio.delete('/api/v1/plants/$id');

      if (response.statusCode != 200) {
        String errorMsg = 'Failed to delete plant';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to delete plant';
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
