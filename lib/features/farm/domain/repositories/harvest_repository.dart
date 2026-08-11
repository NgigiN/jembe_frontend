import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

abstract class HarvestRepository {
  Future<Either<Failure, List<Harvest>>> getHarvests({String? seasonId});
  Future<Either<Failure, Harvest>> addHarvest(Harvest harvest);
  Future<Either<Failure, Harvest>> updateHarvest(Harvest harvest);
  Future<Either<Failure, void>> deleteHarvest(String id);
}