import 'package:equatable/equatable.dart';

class AnnualCostSummaryModel extends Equatable {
  final String year;
  final String cropName;
  final String landName;
  final String farmName;
  final double totalCost;

  const AnnualCostSummaryModel({
    required this.year,
    required this.cropName,
    required this.landName,
    required this.farmName,
    required this.totalCost,
  });

  factory AnnualCostSummaryModel.fromJson(Map<String, dynamic> json) {
    final totalCostValue = json['total_cost'] ?? 0.0;

    return AnnualCostSummaryModel(
      year: (json['year'] ?? '').toString(),
      cropName: (json['crop_name'] ?? '').toString(),
      landName: (json['land_name'] ?? '').toString(),
      farmName: (json['farm_name'] ?? '').toString(),
      totalCost: (totalCostValue as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'crop_name': cropName,
      'land_name': landName,
      'farm_name': farmName,
      'total_cost': totalCost,
    };
  }

  @override
  List<Object?> get props => [year, cropName, landName, farmName, totalCost];
}
