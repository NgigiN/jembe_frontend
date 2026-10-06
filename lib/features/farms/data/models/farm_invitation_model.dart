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
    this.emailSent,
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
      emailSent: json['email_sent'] is bool ? json['email_sent'] as bool : null,
    );
  }

  /// Whether the server actually emailed this invitation.
  ///
  /// Only the create and resend responses carry it, so it is null when the
  /// invitation came from the list endpoint — null means "not stated here",
  /// never "not sent". Lives on the model rather than the entity because it
  /// describes one request's outcome, not the invitation itself: the
  /// invitation is equally valid either way, since it is claimed by signing
  /// in with the invited address rather than from the email.
  final bool? emailSent;
}
