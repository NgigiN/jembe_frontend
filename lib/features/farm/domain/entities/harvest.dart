import 'package:equatable/equatable.dart';

class Harvest extends Equatable {
  const Harvest({
    required this.id,
    required this.seasonId,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.revenueId,
  });

  final String id;
  final String seasonId;
  final double quantity;
  final String unit;
  final DateTime date;
  final String? notes;
  final String? revenueId;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        seasonId,
        quantity,
        unit,
        date,
        notes,
        revenueId,
        createdAt,
        updatedAt,
      ];
}