import 'package:farm_tracker/features/content/domain/entities/content_item.dart';

abstract class ContentRepository {
  Future<List<ContentItem>> getAll();
  Future<List<ContentItem>> forAnimalTypeNames(List<String> animalTypeNames);
  Future<List<ContentItem>> forPlantNames(List<String> plantNames);
}
