import 'package:equatable/equatable.dart';

class CostBreakdown extends Equatable {
  final String seasonId;
  final String seasonName;
  final String cropName;
  final String landName;
  final String inputType;
  final double inputCost;
  final double percentage;

  const CostBreakdown({
    required this.seasonId,
    required this.seasonName,
    required this.cropName,
    required this.landName,
    required this.inputType,
    required this.inputCost,
    required this.percentage,
  });

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
