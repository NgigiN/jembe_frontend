import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';

class AddRevenueParams extends Equatable {
  const AddRevenueParams({
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.date, this.total,
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

class AddRevenue implements UseCase<Revenue, AddRevenueParams> {
  AddRevenue(this.repository);
  final RevenueRepository repository;

  @override
  Future<Either<Failure, Revenue>> call(AddRevenueParams params) async {
    return repository.addRevenue(
      source: params.source,
      sourceId: params.sourceId,
      type: params.type,
      quantity: params.quantity,
      unitPrice: params.unitPrice,
      total: params.total,
      date: params.date,
      notes: params.notes,
    );
  }
}
