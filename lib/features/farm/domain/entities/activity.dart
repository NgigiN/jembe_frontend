import 'package:equatable/equatable.dart';

class Activity extends Equatable {
  final String id;
  final String seasonId;
  final String type;
  final DateTime date;
  final double cost;
  final String? details;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Activity({
    required this.id,
    required this.seasonId,
    required this.type,
    required this.date,
    required this.cost,
    this.details,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    seasonId,
    type,
    date,
    cost,
    details,
    createdAt,
    updatedAt,
  ];
}
