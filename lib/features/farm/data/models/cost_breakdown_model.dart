import 'package:equatable/equatable.dart';

class CostBreakdownModel extends Equatable {
  final String seasonId;
  final String seasonName;
  final String cropName;
  final String landName;
  final String inputType;
  final String farmName;
  final double inputCost;
  final double percentage;
  final String category;

  const CostBreakdownModel({
    required this.seasonId,
    required this.seasonName,
    required this.cropName,
    required this.landName,
    required this.inputType,
    required this.farmName,
    required this.inputCost,
    required this.percentage,
    required this.category,
  });

  factory CostBreakdownModel.fromJson(Map<String, dynamic> json) {
    final inputCostValue = json['input_cost'] ?? 0.0;
    final percentageValue = json['percentage'] ?? 0.0;

    return CostBreakdownModel(
      seasonId: (json['season_id'] ?? '').toString(),
      seasonName: (json['season_name'] ?? '').toString(),
      cropName: (json['crop_name'] ?? '').toString(),
      landName: (json['land_name'] ?? '').toString(),
      inputType: (json['input_type'] ?? '').toString(),
      farmName: (json['farm_name'] ?? '').toString(),
      inputCost: (inputCostValue as num).toDouble(),
      percentage: (percentageValue as num).toDouble(),
      category: (json['category'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season_id': seasonId,
      'season_name': seasonName,
      'crop_name': cropName,
      'land_name': landName,
      'input_type': inputType,
      'farm_name': farmName,
      'input_cost': inputCost,
      'percentage': percentage,
      'category': category,
    };
  }

  @override
  List<Object?> get props => [
    seasonId,
    seasonName,
    cropName,
    landName,
    inputType,
    farmName,
    inputCost,
    percentage,
    category,
  ];
}
