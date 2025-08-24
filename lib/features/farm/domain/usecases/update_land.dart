import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/land.dart';
import '../repositories/land_repository.dart';

class UpdateLand implements UseCase<Land, UpdateLandParams> {
  final LandRepository repository;

  UpdateLand(this.repository);

  @override
  Future<Either<Failure, Land>> call(UpdateLandParams params) async {
    return await repository.updateLand(params.land);
  }
}

class UpdateLandParams {
  final Land land;

  UpdateLandParams({required this.land});
}
