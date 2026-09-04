import 'package:equatable/equatable.dart';

class HerdActivity extends Equatable {
  const HerdActivity({
    required this.id,
    required this.herdId,
    required this.activityType,
    required this.count,
    required this.date,
    required this.createdAt, this.notes,
  });
  final String id;
  final String herdId;
  final String activityType; // "birth" or "fatality"
  final int count;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    herdId,
    activityType,
    count,
    date,
    notes,
    createdAt,
  ];
}
