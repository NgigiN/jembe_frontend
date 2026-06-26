import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

class UpdateHarvest implements UseCase<Harvest, UpdateHarvestParams> {
  UpdateHarvest(this.repository);
  final HarvestRepository repository;

  @override
  Future<Either<Failure, Harvest>> call(UpdateHarvestParams params) async {
    return repository.updateHarvest(params.harvest);
  }
}

class UpdateHarvestParams extends Equatable {
  const UpdateHarvestParams({required this.harvest});
  final Harvest harvest;

  @override
  List<Object?> get props => [harvest];
}