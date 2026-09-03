import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LandModel.create', () {
    test('carries an optional tenureType through', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'owned',
      );

      expect(land.tenureType, 'owned');
    });

    test('defaults tenureType to null when omitted', () {
      final land = LandModel.create(userId: 'user-1', name: 'North Field');

      expect(land.tenureType, isNull);
    });
  });

  group('LandModel.fromJson', () {
    test('parses snake_case tenure_type', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
        'tenure_type': 'rented',
      });

      expect(land.tenureType, 'rented');
    });

    test('parses missing tenure_type as null', () {
      final land = LandModel.fromJson(const {
        'id': '1',
        'user_id': 'user-1',
        'name': 'North Field',
      });

      expect(land.tenureType, isNull);
    });
  });

  group('LandModel.toJson', () {
    test('includes tenure_type', () {
      final land = LandModel.create(
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'owned',
      );

      expect(land.toJson()['tenure_type'], 'owned');
    });
  });
}
