import 'package:equatable/equatable.dart';

class TotalCostsBySeason extends Equatable {
  final String seasonId;
  final String seasonName;
  final DateTime startDate;
  final String cropName;
  final String landName;
  final String farmName;
  final double totalCost;

  const TotalCostsBySeason({
    required this.seasonId,
    required this.seasonName,
    required this.startDate,
    required this.cropName,
    required this.landName,
    required this.farmName,
    required this.totalCost,
  });

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
