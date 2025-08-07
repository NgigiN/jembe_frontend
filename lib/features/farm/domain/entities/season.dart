import 'package:equatable/equatable.dart';

class Season extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String cropId;
  final String landId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Season({
    required this.id,
    required this.userId,
    required this.name,
    required this.cropId,
    required this.landId,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    cropId,
    landId,
    startDate,
    endDate,
    createdAt,
    updatedAt,
  ];
}
