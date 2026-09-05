import 'package:equatable/equatable.dart';

class Input extends Equatable {
  const Input({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.type, required this.cost, required this.date, required this.createdAt, required this.updatedAt, this.animalId,
    this.quantity,
    this.notes,
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
