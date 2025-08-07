import 'package:equatable/equatable.dart';

class AnnualCostSummary extends Equatable {
  final String year;
  final String cropName;
  final String landName;
  final String farmName;
  final double totalCost;

  const AnnualCostSummary({
    required this.year,
    required this.cropName,
    required this.landName,
    required this.farmName,
    required this.totalCost,
  });

  @override
  List<Object?> get props => [year, cropName, landName, farmName, totalCost];
}
