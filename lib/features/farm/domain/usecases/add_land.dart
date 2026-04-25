import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';

class AddLand implements UseCase<Land, AddLandParams> {
  AddLand(this.repository);
  final LandRepository repository;

  @override
  Future<Either<Failure, Land>> call(AddLandParams params) async {
    return repository.addLand(params.land);
  }
}

class AddLandParams {
  AddLandParams({required this.land});
  final Land land;
}
