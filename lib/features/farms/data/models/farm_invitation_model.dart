import 'package:farm_tracker/features/farms/domain/entities/farm_invitation.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class FarmInvitationModel extends FarmInvitation {
  const FarmInvitationModel({
    required super.id,
    required super.email,
    required super.role,
    required super.invitedBy,
    required super.expiresAt,
    required super.createdAt,
  });

  factory FarmInvitationModel.fromJson(Map<String, dynamic> json) {
    final invitedByRaw = json['invited_by'];
    return FarmInvitationModel(
      id: (json['id'] as num).toInt(),
      email: (json['email'] ?? '').toString(),
      role: FarmRole.fromWire((json['role'] ?? '').toString()),
      invitedBy: invitedByRaw is num ? invitedByRaw.toInt() : null,
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}
