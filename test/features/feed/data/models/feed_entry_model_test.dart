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

  test('parses the signed amount and the detail', () {
    final entry = FeedEntryModel.fromJson({
      'entity_type': 'input',
      'summary': 'DAP fertilizer',
      'detail': '50',
      'amount': -6800,
      'logged_by': {'user_id': 1, 'first_name': 'A', 'last_name': 'K'},
      'created_at': '2026-09-22T10:00:00Z',
    });
    expect(entry.detail, '50');
    expect(entry.amount, -6800.0);
  });

  test('an entry with no money has no amount, not a zero', () {
    final entry = FeedEntryModel.fromJson({
      'entity_type': 'harvest',
      'summary': 'Harvest',
      'detail': '18 bags',
      'amount': null,
      'logged_by': null,
      'created_at': '2026-09-22T09:00:00Z',
    });
    expect(entry.amount, isNull);
  });

  test('an empty detail reads as none, so the cell can show a dash', () {
    final entry = FeedEntryModel.fromJson({
      'entity_type': 'activity',
      'summary': 'Weeding',
      'detail': '',
      'logged_by': null,
      'created_at': '2026-09-22T09:00:00Z',
    });
    expect(entry.detail, isNull);
  });

  test('a server that predates the amount/detail fields still parses', () {
    final entry = FeedEntryModel.fromJson({
      'entity_type': 'activity',
      'summary': 'Weeding',
      'logged_by': null,
      'created_at': '2026-09-22T09:00:00Z',
    });
    expect(entry.detail, isNull);
    expect(entry.amount, isNull);
  });
}
