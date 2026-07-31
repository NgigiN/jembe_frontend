import 'package:equatable/equatable.dart';

class CostBreakdown extends Equatable {
  const CostBreakdown({
    required this.category,
    required this.type,
    required this.origin,
    required this.totalCost,
    required this.percentage,
    this.originId,
    this.originType,
  });
  final String category;
  final String type; // 'plant' or 'animal'
  final String origin;
  final double totalCost;
  final double percentage;
  final String? originId;
  final String? originType; // 'season', 'herd', or null for farm-wide

  @override
  List<Object?> get props => [
    category,
    type,
    origin,
    totalCost,
    percentage,
    originId,
    originType,
  ];
}
