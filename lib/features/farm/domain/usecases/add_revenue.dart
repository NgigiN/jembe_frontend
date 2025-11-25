import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/revenue.dart';
import '../repositories/revenue_repository.dart';

class AddRevenueParams extends Equatable {
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double? total;
  final DateTime date;
  final String? notes;

  const AddRevenueParams({
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    this.total,
    required this.date,
    this.notes,
  });

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
  final RevenueRepository repository;

  AddRevenue(this.repository);

  @override
  Future<Either<Failure, Revenue>> call(AddRevenueParams params) async {
    return await repository.addRevenue(
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


