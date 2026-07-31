import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/data/models/cost_breakdown_model.dart';

void main() {
  group('CostBreakdownModel', () {
    test('fromJson parses origin_id and origin_type when present', () {
      final json = {
        'category': 'Seeds',
        'type': 'plant',
        'origin': 'Long Rains 2026',
        'origin_id': 5,
        'origin_type': 'season',
        'total_cost': 500.0,
        'percentage': 40.0,
      };

      final model = CostBreakdownModel.fromJson(json);

      expect(model.originId, '5');
      expect(model.originType, 'season');
    });

    test('fromJson treats a missing origin_id/origin_type as farm-wide', () {
      final json = {
        'category': 'Fence',
        'type': 'animal',
        'origin': 'General',
        'total_cost': 200.0,
        'percentage': 10.0,
      };

      final model = CostBreakdownModel.fromJson(json);

      expect(model.originId, isNull);
      expect(model.originType, isNull);
    });
  });
}
