import 'package:farm_tracker/features/farms/data/models/farm_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FarmModel.fromJson parses every FarmResponse field', () {
    final model = FarmModel.fromJson(const {
      'id': 7,
      'name': 'Green Acres',
      'location': 'Nakuru',
      'fiscal_year_start_month': 3,
      'owner_user_id': 12,
      'successor_user_id': 34,
      'max_members': 10,
      'role': 'manager',
      'member_count': 4,
      'is_default': true,
    });

    expect(model.id, 7);
    expect(model.name, 'Green Acres');
    expect(model.location, 'Nakuru');
    expect(model.fiscalYearStartMonth, 3);
    expect(model.ownerUserId, 12);
    expect(model.successorUserId, 34);
    expect(model.maxMembers, 10);
    expect(model.role, FarmRole.manager);
    expect(model.memberCount, 4);
    expect(model.isDefault, true);
  });

  test('FarmModel.fromJson handles a null successor_user_id', () {
    final model = FarmModel.fromJson(const {
      'id': 1,
      'name': 'Solo Farm',
      'location': '',
      'fiscal_year_start_month': 1,
      'owner_user_id': 1,
      'successor_user_id': null,
      'max_members': 5,
      'role': 'owner',
      'member_count': 1,
      'is_default': true,
    });

    expect(model.successorUserId, isNull);
  });
}
