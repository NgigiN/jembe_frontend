import '../../domain/entities/farm_detailed_cost.dart';

class FarmDetailedCostModel extends FarmDetailedCost {
  const FarmDetailedCostModel({
    required super.totalOverallCost,
    required List<CostDetailModel> super.details,
  });

  factory FarmDetailedCostModel.fromJson(Map<String, dynamic> json) {
    return FarmDetailedCostModel(
      totalOverallCost: (json['total_overall_cost'] ?? 0.0).toDouble(),
      details: (json['details'] as List<dynamic>?)
              ?.map((e) => CostDetailModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_overall_cost': totalOverallCost,
      'details': details
          .map((e) => (e as CostDetailModel).toJson())
          .toList(),
    };
  }
}

class CostDetailModel extends CostDetail {
  const CostDetailModel({
    required super.type,
    required super.id,
    required super.name,
    required super.category,
    required super.location,
    required super.startDate,
    super.endDate,
    required super.inputCost,
    required super.activityCost,
    required super.totalCost,
  });

  factory CostDetailModel.fromJson(Map<String, dynamic> json) {
    return CostDetailModel(
      type: json['type'] ?? '',
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      location: json['location'] ?? '',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      inputCost: (json['input_cost'] ?? 0.0).toDouble(),
      activityCost: (json['activity_cost'] ?? 0.0).toDouble(),
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'name': name,
      'category': category,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'input_cost': inputCost,
      'activity_cost': activityCost,
      'total_cost': totalCost,
    };
  }
}
