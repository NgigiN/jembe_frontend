import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

class GetHarvests implements UseCase<List<Harvest>, GetHarvestsParams> {
  GetHarvests(this.repository);
  final HarvestRepository repository;

  @override
  Future<Either<Failure, List<Harvest>>> call(GetHarvestsParams params) async {
    return repository.getHarvests(seasonId: params.seasonId);
  }
}

class GetHarvestsParams extends Equatable {
  const GetHarvestsParams({this.seasonId});
  final String? seasonId;

  @override
  List<Object?> get props => [seasonId];
}