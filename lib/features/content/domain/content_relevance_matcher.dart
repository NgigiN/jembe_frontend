import 'package:farm_tracker/features/content/domain/entities/content_item.dart';

/// Rules-based, no-ML relevance matching between farmer-entered free text
/// (Plant.name, AnimalType.name - the farmer types these themselves, so
/// there's no controlled vocabulary to match exactly against) and each
/// content item's tag lists.
class ContentRelevanceMatcher {
  const ContentRelevanceMatcher();

  /// The minimum length a farmer-entered value must have before it's allowed
  /// to match a tag via reverse containment (tag contains value). Without
  /// this floor, a short value like "cat" would match a "cattle" tag purely
  /// by coincidence. Forward containment (value contains tag) has no floor -
  /// a longer farmer string containing a short tag, e.g. "yellow maize"
  /// containing "maize", is a real, intentional match either way.
  static const _minReverseMatchLength = 4;

  bool _matchesAny(String farmerValue, List<String> tags) {
    final normalizedValue = farmerValue.trim().toLowerCase();
    if (normalizedValue.isEmpty) return false;
    for (final tag in tags) {
      final normalizedTag = tag.trim().toLowerCase();
      if (normalizedTag.isEmpty) continue;
      if (normalizedValue.contains(normalizedTag)) {
        return true;
      }
      if (normalizedValue.length >= _minReverseMatchLength &&
          normalizedTag.contains(normalizedValue)) {
        return true;
      }
    }
    return false;
  }

  List<ContentItem> forAnimalTypeNames(
    List<ContentItem> items,
    List<String> animalTypeNames,
  ) {
    return items
        .where(
          (item) =>
              item.animalTypeTags.isNotEmpty &&
              animalTypeNames.any(
                (name) => _matchesAny(name, item.animalTypeTags),
              ),
        )
        .toList();
  }

  List<ContentItem> forPlantNames(
    List<ContentItem> items,
    List<String> plantNames,
  ) {
    return items
        .where(
          (item) =>
              item.cropTags.isNotEmpty &&
              plantNames.any((name) => _matchesAny(name, item.cropTags)),
        )
        .toList();
  }
}
