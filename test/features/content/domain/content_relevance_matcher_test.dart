import 'package:farm_tracker/features/content/domain/content_relevance_matcher.dart';
import 'package:farm_tracker/features/content/domain/entities/content_item.dart';
import 'package:flutter_test/flutter_test.dart';

ContentItem _item({
  List<String> animalTypeTags = const [],
  List<String> cropTags = const [],
}) {
  return ContentItem(
    id: 'x',
    title: 'title',
    summary: 'summary',
    body: 'body',
    language: 'en',
    source: 'source',
    animalTypeTags: animalTypeTags,
    cropTags: cropTags,
    publishedAt: DateTime(2026, 8),
  );
}

void main() {
  const matcher = ContentRelevanceMatcher();

  group('forAnimalTypeNames', () {
    test('matches when farmer value exactly equals a tag, case-insensitively', () {
      final item = _item(animalTypeTags: ['Dairy Cattle']);
      final result = matcher.forAnimalTypeNames([item], ['dairy cattle']);
      expect(result, [item]);
    });

    test('matches when the farmer value contains the tag', () {
      final item = _item(animalTypeTags: ['maize']);
      final result = matcher.forAnimalTypeNames([item], ['yellow maize']);
      expect(result, [item]);
    });

    test('matches when the tag contains the farmer value', () {
      final item = _item(animalTypeTags: ['kienyeji chicken']);
      final result = matcher.forAnimalTypeNames([item], ['chicken']);
      expect(result, [item]);
    });

    test('does not match unrelated values', () {
      final item = _item(animalTypeTags: ['dairy cattle']);
      final result = matcher.forAnimalTypeNames([item], ['goats']);
      expect(result, isEmpty);
    });

    test('an item with no animalTypeTags never matches, even with an empty farmer list', () {
      final item = _item();
      expect(matcher.forAnimalTypeNames([item], []), isEmpty);
      expect(matcher.forAnimalTypeNames([item], ['anything']), isEmpty);
    });

    test(
      'a short farmer value does not match via reverse containment (e.g. "Cat" vs "cattle")',
      () {
        final item = _item(animalTypeTags: ['cattle']);
        final result = matcher.forAnimalTypeNames([item], ['Cat']);
        expect(result, isEmpty);
      },
    );
  });

  group('forPlantNames', () {
    test('matches crop tags the same way', () {
      final item = _item(cropTags: ['maize']);
      final result = matcher.forPlantNames([item], ['Maize']);
      expect(result, [item]);
    });
  });
}
