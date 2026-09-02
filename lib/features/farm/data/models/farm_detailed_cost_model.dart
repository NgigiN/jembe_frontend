import 'package:farm_tracker/features/farm/domain/entities/farm_detailed_cost.dart';

class FarmDetailedCostModel extends FarmDetailedCost {
  const FarmDetailedCostModel({required List<CostDetailModel> super.details});

  factory FarmDetailedCostModel.fromJson(Map<String, dynamic> json) {
    return FarmDetailedCostModel(
      details:
          (json['details'] as List<dynamic>?)
              ?.map((e) => CostDetailModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'details': details.map((e) => (e as CostDetailModel).toJson()).toList(),
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
    required super.inputCost,
    required super.activityCost,
    required super.totalCost,
    super.endDate,
  });

  factory CostDetailModel.fromJson(Map<String, dynamic> json) {
    return CostDetailModel(
      type: (json['type'] as String?) ?? '',
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      startDate: DateTime.parse(
        (json['start_date'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      inputCost: ((json['input_cost'] as num?) ?? 0).toDouble(),
      activityCost: ((json['activity_cost'] as num?) ?? 0).toDouble(),
      totalCost: ((json['total_cost'] as num?) ?? 0).toDouble(),
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
