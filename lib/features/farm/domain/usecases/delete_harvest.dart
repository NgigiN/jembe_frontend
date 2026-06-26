import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

class DeleteHarvest implements UseCase<void, DeleteHarvestParams> {
  DeleteHarvest(this.repository);
  final HarvestRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteHarvestParams params) async {
    return repository.deleteHarvest(params.id);
  }
}

class DeleteHarvestParams {
  DeleteHarvestParams({required this.id});
  final String id;
}