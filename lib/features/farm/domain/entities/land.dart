import 'package:equatable/equatable.dart';

class Land extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double? size;
  final String? location;
  final String? soilType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Land({
    required this.id,
    required this.userId,
    required this.name,
    this.size,
    this.location,
    this.soilType,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    size,
    location,
    soilType,
    createdAt,
    updatedAt,
  ];
}
