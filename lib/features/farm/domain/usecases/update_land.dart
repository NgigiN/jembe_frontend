import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';

class UpdateLand implements UseCase<Land, UpdateLandParams> {
  UpdateLand(this.repository);
  final LandRepository repository;

  @override
  Future<Either<Failure, Land>> call(UpdateLandParams params) async {
    return repository.updateLand(params.land);
  }
}

class UpdateLandParams {
  UpdateLandParams({required this.land});
  final Land land;
}
