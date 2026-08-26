import 'dart:convert';
import 'dart:io';

import 'package:farm_tracker/features/content/data/models/content_item_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the real bundled asset directly from disk with dart:io - not via
/// rootBundle, which needs a Flutter test binding - so this test exercises
/// the actual shipped file, not a stand-in inline map. Every other content
/// test parses inline fixtures; this is the one guard that would catch a
/// real authoring mistake (bad JSON, a missing source, a duplicate id) in
/// assets/content/tips.json before it ships.
void main() {
  group('assets/content/tips.json', () {
    test('every entry parses via ContentItemModel.fromJson without throwing', () {
      final raw = File('assets/content/tips.json').readAsStringSync();
      final decoded = json.decode(raw) as List<dynamic>;

      final items = decoded
          .map((e) => ContentItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(items, isNotEmpty);
    });

    test('every id is unique', () {
      final raw = File('assets/content/tips.json').readAsStringSync();
      final decoded = json.decode(raw) as List<dynamic>;
      final items = decoded
          .map((e) => ContentItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      final ids = items.map((item) => item.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: "Duplicate content ids would make ContentDetailPage's "
            '.firstOrNull lookup silently resolve to the wrong item.',
      );
    });
  });
}
