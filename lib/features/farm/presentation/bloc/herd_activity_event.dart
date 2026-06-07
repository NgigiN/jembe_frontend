import 'package:equatable/equatable.dart';

abstract class HerdActivityEvent extends Equatable {
  const HerdActivityEvent();

  @override
  List<Object?> get props => [];
}

class AddHerdActivityEvent extends HerdActivityEvent {
  const AddHerdActivityEvent({
    required this.herdId,
    required this.activityType,
    required this.count,
    required this.date,
    this.notes,
  });
  final String herdId;
  final String activityType;
  final int count;
  final DateTime date;
  final String? notes;

  @override
  List<Object?> get props => [herdId, activityType, count, date, notes];
}
