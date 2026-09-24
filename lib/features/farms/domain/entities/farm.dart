import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class Farm extends Equatable {
  const Farm({
    required this.id,
    required this.name,
    required this.location,
    required this.fiscalYearStartMonth,
    required this.ownerUserId,
    required this.successorUserId,
    required this.maxMembers,
    required this.role,
    required this.memberCount,
    required this.isDefault,
  });

  final int id;
  final String name;
  final String location;
  final int fiscalYearStartMonth;
  final int ownerUserId;
  final int? successorUserId;
  final int maxMembers;
  final FarmRole role;
  final int memberCount;
  final bool isDefault;

  @override
  List<Object?> get props => [
    id, name, location, fiscalYearStartMonth, ownerUserId,
    successorUserId, maxMembers, role, memberCount, isDefault,
  ];
}
