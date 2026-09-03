import 'package:farm_tracker/features/farm/data/models/herd_activity_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HerdActivityModel', () {
    test('toJson sends reason under the backend field name', () {
      final model = HerdActivityModel.create(
        herdId: '1',
        activityType: 'fatality',
        count: 2,
        date: DateTime.utc(2026, 9),
        notes: 'lion attack',
      );
      final json = model.toJson();
      expect(json['reason'], 'lion attack');
      expect(json.containsKey('notes'), isFalse);
    });

    test('fromJson reads the backend reason field', () {
      final model = HerdActivityModel.fromJson(const {
        'ID': 7,
        'herd_id': 1,
        'activity_type': 'fatality',
        'count': 2,
        'date': '2026-09-01T00:00:00Z',
        'reason': 'lion attack',
        'CreatedAt': '2026-09-01T10:00:00Z',
      });
      expect(model.notes, 'lion attack');
    });
  });
}
