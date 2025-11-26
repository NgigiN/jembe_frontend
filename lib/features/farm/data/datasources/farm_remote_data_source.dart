import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/land_model.dart';
import '../models/plant_model.dart';
import '../models/season_model.dart';
import '../models/activity_model.dart';

abstract class FarmRemoteDataSource {
  Future<List<LandModel>> getLands();
  Future<LandModel> addLand(String name);
  Future<LandModel> updateLand(String id, String name);
  Future<List<PlantModel>> getPlants();
  Future<PlantModel> addPlant(String name);
  Future<PlantModel> updatePlant(String id, String name);
  Future<List<SeasonModel>> getSeasons();
  Future<SeasonModel> addSeason(String name);
  Future<SeasonModel> updateSeason(String id, String name);
  Future<List<ActivityModel>> getActivities();
  Future<ActivityModel> addActivity(String description);
}

class FarmRemoteDataSourceImpl implements FarmRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  FarmRemoteDataSourceImpl({required this.dio, required this.baseUrl});

  @override
  Future<List<LandModel>> getLands() async {
    try {
      final response = await dio.get('/api/collections/lands/records');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List;
        return items
            .map((json) => LandModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Failed to load lands');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<LandModel> addLand(String name) async {
    try {
      final response = await dio.post(
        '/api/collections/lands/records',
        data: {'name': name},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return LandModel.fromJson(data);
      } else {
        throw ServerException('Failed to add land');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<LandModel> updateLand(String id, String name) async {
    try {
      final response = await dio.patch(
        '/api/collections/lands/records/$id',
        data: {'name': name},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return LandModel.fromJson(data);
      } else {
        throw ServerException('Failed to update land');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<List<PlantModel>> getPlants() async {
    try {
      final response = await dio.get('/api/collections/crops/records');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List;
        return items
            .map((json) => PlantModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Failed to load plants');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<PlantModel> addPlant(String name) async {
    try {
      final response = await dio.post(
        '/api/collections/crops/records',
        data: {'name': name},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
      } else {
        throw ServerException('Failed to add plant');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<PlantModel> updatePlant(String id, String name) async {
    try {
      final response = await dio.patch(
        '/api/collections/crops/records/$id',
        data: {'name': name},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return PlantModel.fromJson(data);
      } else {
        throw ServerException('Failed to update plant');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<List<SeasonModel>> getSeasons() async {
    try {
      final response = await dio.get('/api/collections/seasons/records');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List;
        return items
            .map((json) => SeasonModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Failed to load seasons');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<SeasonModel> addSeason(String name) async {
    try {
      final response = await dio.post(
        '/api/collections/seasons/records',
        data: {'name': name},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return SeasonModel.fromJson(data);
      } else {
        throw ServerException('Failed to add season');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<SeasonModel> updateSeason(String id, String name) async {
    try {
      final response = await dio.patch(
        '/api/collections/seasons/records/$id',
        data: {'name': name},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return SeasonModel.fromJson(data);
      } else {
        throw ServerException('Failed to update season');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<List<ActivityModel>> getActivities() async {
    try {
      final response = await dio.get('/api/collections/activities/records');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['items'] as List;
        return items
            .map((json) => ActivityModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException('Failed to load activities');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }

  @override
  Future<ActivityModel> addActivity(String description) async {
    try {
      final response = await dio.post(
        '/api/collections/activities/records',
        data: {'description': description},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return ActivityModel.fromJson(data);
      } else {
        throw ServerException('Failed to add activity');
      }
    } on DioException catch (e) {
      throw ServerException('Network error: ${e.message}');
    }
  }
}
