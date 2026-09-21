import 'package:farm_tracker/features/farms/data/models/farm_invitation_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FarmInvitationModel.fromJson parses every InvitationResponse field', () {
    final model = FarmInvitationModel.fromJson(const {
      'id': 3,
      'email': 'worker@example.com',
      'role': 'worker',
      'invited_by': 9,
      'expires_at': '2026-10-01T00:00:00Z',
      'created_at': '2026-09-21T00:00:00Z',
    });

    expect(model.id, 3);
    expect(model.email, 'worker@example.com');
    expect(model.role, FarmRole.worker);
    expect(model.invitedBy, 9);
    expect(model.expiresAt, DateTime.parse('2026-10-01T00:00:00Z'));
  });

  test('FarmInvitationModel.fromJson handles a null invited_by', () {
    final model = FarmInvitationModel.fromJson(const {
      'id': 4,
      'email': 'x@example.com',
      'role': 'manager',
      'invited_by': null,
      'expires_at': '2026-10-01T00:00:00Z',
      'created_at': '2026-09-21T00:00:00Z',
    });

    expect(model.invitedBy, isNull);
  });
}
