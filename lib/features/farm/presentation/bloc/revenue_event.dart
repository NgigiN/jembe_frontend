import 'package:equatable/equatable.dart';

abstract class RevenueEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadRevenues extends RevenueEvent {

  LoadRevenues({this.source, this.startDate, this.endDate});
  final String? source;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [source, startDate, endDate];
}


class AddRevenueEvent extends RevenueEvent {

  AddRevenueEvent({
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    this.total,
    required this.date,
    this.notes,
  });
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double? total;
  final DateTime date;
  final String? notes;

  @override
  List<Object?> get props => [
        source,
        sourceId,
        type,
        quantity,
        unitPrice,
        total,
        date,
        notes,
      ];
}

class UpdateRevenueEvent extends RevenueEvent {

  UpdateRevenueEvent({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.date,
    this.notes,
  });
  final String id;
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double total;
  final DateTime date;
  final String? notes;

  @override
  List<Object?> get props => [
        id,
        source,
        sourceId,
        type,
        quantity,
        unitPrice,
        total,
        date,
        notes,
      ];
}

class DeleteRevenueEvent extends RevenueEvent {

  DeleteRevenueEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}


