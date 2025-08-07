import 'package:equatable/equatable.dart';

class CostBreakdownModel extends Equatable {
  final String seasonId;
  final String seasonName;
  final String cropName;
  final String landName;
  final String inputType;
  final double inputCost;
  final double percentage;

  const CostBreakdownModel({
    required this.seasonId,
    required this.seasonName,
    required this.cropName,
    required this.landName,
    required this.inputType,
    required this.inputCost,
    required this.percentage,
  });

  factory CostBreakdownModel.fromJson(Map<String, dynamic> json) {
    return CostBreakdownModel(
      seasonId: json['season_id'] ?? '',
      seasonName: json['season_name'] ?? '',
      cropName: json['crop_name'] ?? '',
      landName: json['land_name'] ?? '',
      inputType: json['input_type'] ?? '',
      inputCost: (json['input_cost'] ?? 0.0).toDouble(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season_id': seasonId,
      'season_name': seasonName,
      'crop_name': cropName,
      'land_name': landName,
      'input_type': inputType,
      'input_cost': inputCost,
      'percentage': percentage,
    };
  }

  @override
  List<Object?> get props => [
    seasonId,
    seasonName,
    cropName,
    landName,
    inputType,
    inputCost,
    percentage,
  ];
}
