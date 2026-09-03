import 'package:equatable/equatable.dart';

class Revenue extends Equatable {
  const Revenue({
    required this.id,
    required this.userId,
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.date,
    required this.createdAt, required this.updatedAt, this.notes,
  });
  final String id;
  final String userId;
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double total;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    source,
    sourceId,
    type,
    quantity,
    unitPrice,
    total,
    date,
    notes,
    createdAt,
    updatedAt,
  ];
}
