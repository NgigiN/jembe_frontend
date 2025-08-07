import 'package:equatable/equatable.dart';

class TotalCostsBySeasonModel extends Equatable {
  final String seasonId;
  final String seasonName;
  final DateTime startDate;
  final String cropName;
  final String landName;
  final String farmName;
  final double totalCost;

  const TotalCostsBySeasonModel({
    required this.seasonId,
    required this.seasonName,
    required this.startDate,
    required this.cropName,
    required this.landName,
    required this.farmName,
    required this.totalCost,
  });

  factory TotalCostsBySeasonModel.fromJson(Map<String, dynamic> json) {
    return TotalCostsBySeasonModel(
      seasonId: json['season_id'] ?? '',
      seasonName: json['season_name'] ?? '',
      startDate: DateTime.parse(
        json['start_date'] ?? DateTime.now().toIso8601String(),
      ),
      cropName: json['crop_name'] ?? '',
      landName: json['land_name'] ?? '',
      farmName: json['farm_name'] ?? '',
      totalCost: (json['total_cost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season_id': seasonId,
      'season_name': seasonName,
      'start_date': startDate.toIso8601String(),
      'crop_name': cropName,
      'land_name': landName,
      'farm_name': farmName,
      'total_cost': totalCost,
    };
  }

  @override
  List<Object?> get props => [
    seasonId,
    seasonName,
    startDate,
    cropName,
    landName,
    farmName,
    totalCost,
  ];
}
