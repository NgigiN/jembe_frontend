import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class FarmMember extends Equatable {
  const FarmMember({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  final int userId;
  final String firstName;
  final String lastName;
  final String email;
  final FarmRole role;
  final DateTime joinedAt;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [userId, firstName, lastName, email, role, joinedAt];
}
