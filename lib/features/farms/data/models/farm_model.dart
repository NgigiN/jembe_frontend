import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class FarmModel extends Farm {
  const FarmModel({
    required super.id,
    required super.name,
    required super.location,
    required super.fiscalYearStartMonth,
    required super.ownerUserId,
    required super.successorUserId,
    required super.maxMembers,
    required super.role,
    required super.memberCount,
    required super.isDefault,
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    final successorRaw = json['successor_user_id'];
    return FarmModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      fiscalYearStartMonth: (json['fiscal_year_start_month'] as num).toInt(),
      ownerUserId: (json['owner_user_id'] as num).toInt(),
      successorUserId: successorRaw is num ? successorRaw.toInt() : null,
      maxMembers: (json['max_members'] as num).toInt(),
      role: FarmRole.fromWire((json['role'] ?? '').toString()),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'fiscal_year_start_month': fiscalYearStartMonth,
    'owner_user_id': ownerUserId,
    'successor_user_id': successorUserId,
    'max_members': maxMembers,
    'role': role.wireValue,
    'member_count': memberCount,
    'is_default': isDefault,
  };
}
