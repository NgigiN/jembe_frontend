import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class FarmInvitation extends Equatable {
  const FarmInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.invitedBy,
    required this.expiresAt,
    required this.createdAt,
  });

  final int id;
  final String email;
  final FarmRole role;
  final int? invitedBy;
  final DateTime expiresAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, email, role, invitedBy, expiresAt, createdAt];
}
