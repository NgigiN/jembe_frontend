import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/animal_type_model.dart';

abstract class AnimalTypeRemoteDataSource {
  Future<List<AnimalTypeModel>> getAnimalTypes();
  Future<AnimalTypeModel> getAnimalType(String id);
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType);
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType);
  Future<void> deleteAnimalType(String id);
}

class AnimalTypeRemoteDataSourceImpl implements AnimalTypeRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  AnimalTypeRemoteDataSourceImpl({required this.dio, required this.baseUrl});

  @override
  Future<List<AnimalTypeModel>> getAnimalTypes() async {
    try {
      final response = await dio.get('/api/v1/animal-types');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) return [];
        if (data is List) {
          return data
              .map((json) => AnimalTypeModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        String errorMsg = 'Failed to load animal types';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to load animal types';
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
  Future<AnimalTypeModel> getAnimalType(String id) async {
    try {
      final response = await dio.get('/api/v1/animal-types/$id');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AnimalTypeModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to load animal type';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to load animal type';
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
  Future<AnimalTypeModel> addAnimalType(AnimalTypeModel animalType) async {
    try {
      final response = await dio.post(
        '/api/v1/animal-types',
        data: animalType.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AnimalTypeModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to add animal type';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to add animal type';
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
  Future<AnimalTypeModel> updateAnimalType(AnimalTypeModel animalType) async {
    try {
      final response = await dio.put(
        '/api/v1/animal-types/${animalType.id}',
        data: animalType.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AnimalTypeModel.fromJson(data);
      } else {
        String errorMsg = 'Failed to update animal type';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to update animal type';
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
  Future<void> deleteAnimalType(String id) async {
    try {
      final response = await dio.delete('/api/v1/animal-types/$id');

      if (response.statusCode != 200 && response.statusCode != 204) {
        String errorMsg = 'Failed to delete animal type';
        try {
          final errorData = response.data as Map<String, dynamic>?;
          if (errorData != null && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        throw ServerException(errorMsg);
      }
    } on DioException catch (e) {
      String errorMsg = 'Failed to delete animal type';
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
