import 'package:equatable/equatable.dart';

class FarmDetailedCost extends Equatable {
  const FarmDetailedCost({
    required this.totalOverallCost,
    required this.details,
  });
  final double totalOverallCost;
  final List<CostDetail> details;

  @override
  List<Object?> get props => [totalOverallCost, details];
}

class CostDetail extends Equatable {
  const CostDetail({
    required this.type,
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.startDate,
    this.endDate,
    required this.inputCost,
    required this.activityCost,
    required this.totalCost,
  });
  final String type; // 'plant' or 'animal'
  final int id;
  final String name;
  final String category;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double inputCost;
  final double activityCost;
  final double totalCost;

  @override
  List<Object?> get props => [
    type,
    id,
    name,
    category,
    location,
    startDate,
    endDate,
    inputCost,
    activityCost,
    totalCost,
  ];
}
