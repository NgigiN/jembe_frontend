import 'package:equatable/equatable.dart';

class Input extends Equatable {
  final String id;
  final String seasonId;
  final String type;
  final double? quantity;
  final double cost;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Input({
    required this.id,
    required this.seasonId,
    required this.type,
    this.quantity,
    required this.cost,
    required this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    seasonId,
    type,
    quantity,
    cost,
    date,
    notes,
    createdAt,
    updatedAt,
  ];
}
