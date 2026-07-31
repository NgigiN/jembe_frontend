import 'package:equatable/equatable.dart';

class CostBreakdownModel extends Equatable {
  const CostBreakdownModel({
    required this.category,
    required this.type,
    required this.origin,
    required this.totalCost,
    required this.percentage,
    this.originId,
    this.originType,
  });

  factory CostBreakdownModel.fromJson(Map<String, dynamic> json) {
    return CostBreakdownModel(
      category: (json['category'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      origin: (json['origin'] ?? '').toString(),
      originId: json['origin_id']?.toString(),
      originType: json['origin_type']?.toString(),
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
    );
  }
  final String category;
  final String type;
  final String origin;
  final String? originId;
  final String? originType;
  final double totalCost;
  final double percentage;

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'type': type,
      'origin': origin,
      'origin_id': originId,
      'origin_type': originType,
      'total_cost': totalCost,
      'percentage': percentage,
    };
  }

  @override
  List<Object?> get props => [
    category,
    type,
    origin,
    originId,
    originType,
    totalCost,
    percentage,
  ];
}
