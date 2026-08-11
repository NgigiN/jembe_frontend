import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/data/models/farm_detailed_cost_model.dart';

void main() {
  group('FarmDetailedCostModel', () {
    test('fromJson parses details without totalOverallCost', () {
      final json = {
        'details': [
          {
            'type': 'plant',
            'id': 1,
            'name': 'Long Rains 2026',
            'category': 'Maize',
            'location': 'Field A',
            'start_date': '2026-03-01T00:00:00Z',
            'end_date': null,
            'input_cost': 500.0,
            'activity_cost': 200.0,
            'total_cost': 700.0,
          },
        ],
      };

      final model = FarmDetailedCostModel.fromJson(json);

      expect(model.details, hasLength(1));
      expect(model.details.first.name, 'Long Rains 2026');
      expect(model.details.first.totalCost, 700.0);
    });
  });
}
