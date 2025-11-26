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
    final startDateValue = json['start_date'] ?? DateTime.now().toIso8601String();
    final totalCostValue = json['total_cost'] ?? 0.0;

    return TotalCostsBySeasonModel(
      seasonId: (json['season_id'] ?? '').toString(),
      seasonName: (json['season_name'] ?? '').toString(),
      startDate: DateTime.parse(startDateValue.toString()),
      cropName: (json['crop_name'] ?? '').toString(),
      landName: (json['land_name'] ?? '').toString(),
      farmName: (json['farm_name'] ?? '').toString(),
      totalCost: (totalCostValue as num).toDouble(),
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
