import 'package:equatable/equatable.dart';

class CostBreakdown extends Equatable {
  final String category;
  final String type; // 'plant' or 'animal'
  final String origin;
  final double totalCost;
  final double percentage;

  const CostBreakdown({
    required this.category,
    required this.type,
    required this.origin,
    required this.totalCost,
    required this.percentage,
  });

  @override
  List<Object?> get props => [
    category,
    type,
    origin,
    totalCost,
    percentage,
  ];
}
