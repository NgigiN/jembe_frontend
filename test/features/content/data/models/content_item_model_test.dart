import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/content/data/models/content_item_model.dart';

void main() {
  group('ContentItemModel', () {
    test('fromJson parses all fields including tag lists', () {
      final json = {
        'id': 'dairy-mastitis-prevention',
        'title': 'Preventing mastitis in dairy cattle',
        'summary': 'Three habits that cut mastitis risk.',
        'body': 'Full guidance text.',
        'language': 'en',
        'source': 'KALRO Dairy Cattle Production Manual',
        'animalTypeTags': ['dairy cattle', 'cattle'],
        'cropTags': <String>[],
        'publishedAt': '2026-08-01',
      };

      final model = ContentItemModel.fromJson(json);

      expect(model.id, 'dairy-mastitis-prevention');
      expect(model.animalTypeTags, ['dairy cattle', 'cattle']);
      expect(model.cropTags, isEmpty);
      expect(model.publishedAt, DateTime.parse('2026-08-01'));
    });

    test('fromJson throws when source is missing or blank', () {
      final missingSource = {
        'id': 'x',
        'title': 'x',
        'summary': 'x',
        'body': 'x',
        'language': 'en',
        'animalTypeTags': <String>[],
        'cropTags': <String>[],
        'publishedAt': '2026-08-01',
      };
      expect(() => ContentItemModel.fromJson(missingSource), throwsFormatException);

      final blankSource = {...missingSource, 'source': '   '};
      expect(() => ContentItemModel.fromJson(blankSource), throwsFormatException);
    });
  });
}
