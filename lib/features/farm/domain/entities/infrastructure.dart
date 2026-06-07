import 'package:equatable/equatable.dart';

class Infrastructure extends Equatable {
  const Infrastructure({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.location,
    required this.cost,
    required this.date,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String type; // e.g., "Store", "House", "Fence"
  final String name;
  final String location;
  final double cost;
  final DateTime date;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        name,
        location,
        cost,
        date,
        notes,
        createdAt,
        updatedAt,
      ];
}
