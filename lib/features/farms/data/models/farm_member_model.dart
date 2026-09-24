import 'package:farm_tracker/features/farms/domain/entities/farm_member.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class FarmMemberModel extends FarmMember {
  const FarmMemberModel({
    required super.userId,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.role,
    required super.joinedAt,
  });

  factory FarmMemberModel.fromJson(Map<String, dynamic> json) {
    return FarmMemberModel(
      userId: (json['user_id'] as num).toInt(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: FarmRole.fromWire((json['role'] ?? '').toString()),
      joinedAt: DateTime.parse(json['joined_at'].toString()),
    );
  }
}
