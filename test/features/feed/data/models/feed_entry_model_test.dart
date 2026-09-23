import 'package:farm_tracker/features/feed/data/models/feed_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a row with logged_by', () {
    final entry = FeedEntryModel.fromJson({
      'entity_type': 'activity',
      'summary': 'Activity: watering',
      'logged_by': {'user_id': 1, 'first_name': 'Amina', 'last_name': 'Kamau'},
      'created_at': '2026-09-22T10:00:00Z',
    });
    expect(entry.entityType, 'activity');
    expect(entry.summary, 'Activity: watering');
    expect(entry.loggedByUserId, 1);
    expect(entry.loggedByFirstName, 'Amina');
    expect(entry.loggedByLastName, 'Kamau');
    expect(entry.createdAt, DateTime.parse('2026-09-22T10:00:00Z'));
  });

  test('parses a row with logged_by null (former member)', () {
    final entry = FeedEntryModel.fromJson({
      'entity_type': 'harvest',
      'summary': 'Harvest: 10 kg',
      'logged_by': null,
      'created_at': '2026-09-22T09:00:00Z',
    });
    expect(entry.loggedByUserId, isNull);
    expect(entry.loggedByFirstName, isNull);
  });
}
