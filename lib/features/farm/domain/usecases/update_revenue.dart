import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/revenue.dart';
import '../repositories/revenue_repository.dart';

class UpdateRevenueParams extends Equatable {
  final String id;
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double total;
  final DateTime date;
  final String? notes;

  const UpdateRevenueParams({
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

class UpdateRevenue implements UseCase<Revenue, UpdateRevenueParams> {
  final RevenueRepository repository;

  UpdateRevenue(this.repository);

  @override
  Future<Either<Failure, Revenue>> call(UpdateRevenueParams params) async {
    return await repository.updateRevenue(
      id: params.id,
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


