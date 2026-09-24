import 'package:farm_tracker/features/farms/data/models/farm_member_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FarmMemberModel.fromJson parses every MemberResponse field', () {
    final model = FarmMemberModel.fromJson(const {
      'user_id': 5,
      'first_name': 'Amina',
      'last_name': 'Otieno',
      'email': 'amina@example.com',
      'role': 'worker',
      'joined_at': '2026-09-01T10:00:00Z',
    });

    expect(model.userId, 5);
    expect(model.fullName, 'Amina Otieno');
    expect(model.email, 'amina@example.com');
    expect(model.role, FarmRole.worker);
    expect(model.joinedAt, DateTime.parse('2026-09-01T10:00:00Z'));
  });
}
