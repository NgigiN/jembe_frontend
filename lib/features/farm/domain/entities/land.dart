import 'package:equatable/equatable.dart';

class Land extends Equatable {
  const Land({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt, required this.updatedAt, this.size,
    this.location,
    this.soilType,
    this.tenureType,
  });
  final String id;
  final String userId;
  final String name;
  final double? size;
  final String? location;
  final String? soilType;

  /// "owned" or "rented". Null means not recorded.
  final String? tenureType;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    size,
    location,
    soilType,
    tenureType,
    createdAt,
    updatedAt,
  ];
}
