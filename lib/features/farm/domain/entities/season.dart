import 'package:equatable/equatable.dart';

class Season extends Equatable {
  const Season({
    required this.id,
    required this.userId,
    required this.name,
    required this.plantId,
    required this.landId,
    required this.startDate,
    required this.createdAt, required this.updatedAt, this.endDate,
  });
  final String id;
  final String userId;
  final String name;
  final String plantId;
  final String landId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    plantId,
    landId,
    startDate,
    endDate,
    createdAt,
    updatedAt,
  ];
}
