import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HerdModel', () {
    test('fromJson parses start_date and end_date', () {
      final json = {
        'id': 1,
        'user_id': 7,
        'name': 'Broiler Batch 1',
        'animal_type_id': 2,
        'location': 'Coop A',
        'initial_head_count': 100,
        'current_head_count': 100,
        'start_date': '2026-03-01T00:00:00Z',
        'end_date': '2026-04-20T00:00:00Z',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      };

      final herd = HerdModel.fromJson(json);

      expect(herd.startDate, DateTime.parse('2026-03-01T00:00:00Z'));
      expect(herd.endDate, DateTime.parse('2026-04-20T00:00:00Z'));
    });

    test('fromJson treats a missing end_date as ongoing (null)', () {
      final json = {
        'id': 1,
        'user_id': 7,
        'name': 'Dairy Herd A',
        'animal_type_id': 3,
        'location': 'Paddock',
        'initial_head_count': 10,
        'current_head_count': 10,
        'start_date': '2024-01-01T00:00:00Z',
        'end_date': null,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final herd = HerdModel.fromJson(json);

      expect(herd.endDate, isNull);
    });

    test('toJson sends full ISO8601 UTC timestamps for start/end date', () {
      final herd = HerdModel(
        id: '1',
        userId: '7',
        name: 'Broiler Batch 1',
        animalTypeId: '2',
        location: 'Coop A',
        initialHeadCount: 100,
        currentHeadCount: 100,
        startDate: DateTime.utc(2026, 3),
        endDate: DateTime.utc(2026, 4, 20),
        createdAt: DateTime.utc(2026, 3),
        updatedAt: DateTime.utc(2026, 3),
      );

      final json = herd.toJson();

      expect(json['start_date'], '2026-03-01T00:00:00.000Z');
      expect(json['end_date'], '2026-04-20T00:00:00.000Z');
    });
  });
}
