import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

class AddHarvest implements UseCase<Harvest, AddHarvestParams> {
  AddHarvest(this.repository);
  final HarvestRepository repository;

  @override
  Future<Either<Failure, Harvest>> call(AddHarvestParams params) async {
    return repository.addHarvest(params.harvest);
  }
}

class AddHarvestParams extends Equatable {
  const AddHarvestParams({required this.harvest});
  final Harvest harvest;

  @override
  List<Object?> get props => [harvest];
}