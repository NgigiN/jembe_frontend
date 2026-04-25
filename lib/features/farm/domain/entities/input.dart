import 'package:equatable/equatable.dart';

class Input extends Equatable {
  const Input({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    this.animalId,
    required this.type,
    this.quantity,
    required this.cost,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String sourceType;
  final String sourceId;
  final int? animalId;
  final String type;
  final double? quantity;
  final double cost;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    sourceType,
    sourceId,
    animalId,
    type,
    quantity,
    cost,
    date,
    notes,
    createdAt,
    updatedAt,
  ];
}
