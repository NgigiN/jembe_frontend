import 'package:farm_tracker/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('fromJson parses fiscal_year_start_month', () {
      final json = {
        'id': '1',
        'email': 'a@example.com',
        'first_name': 'A',
        'last_name': 'B',
        'farm_name': 'Green Acres',
        'location': 'Nakuru',
        'fiscal_year_start_month': 7,
      };

      final user = UserModel.fromJson(json);

      expect(user.fiscalYearStartMonth, 7);
    });

    test('fromJson defaults to January when the field is missing', () {
      final json = {
        'id': '1',
        'email': 'a@example.com',
        'first_name': 'A',
        'last_name': 'B',
      };

      final user = UserModel.fromJson(json);

      expect(user.fiscalYearStartMonth, 1);
    });
  });
}
