import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/revenue.dart';

abstract class RevenueRepository {
  Future<Either<Failure, List<Revenue>>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<Either<Failure, Revenue>> getRevenueById(String id);
  Future<Either<Failure, Revenue>> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    double? total,
    required DateTime date,
    String? notes,
  });
  Future<Either<Failure, Revenue>> updateRevenue({
    required String id,
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required double total,
    required DateTime date,
    String? notes,
  });
  Future<Either<Failure, void>> deleteRevenue(String id);
}


