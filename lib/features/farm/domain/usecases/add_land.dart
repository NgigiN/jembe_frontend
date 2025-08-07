import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/land.dart';
import '../repositories/land_repository.dart';

class AddLand implements UseCase<Land, AddLandParams> {
  final LandRepository repository;

  AddLand(this.repository);

  @override
  Future<Either<Failure, Land>> call(AddLandParams params) async {
    return await repository.addLand(params.land);
  }
}

class AddLandParams {
  final Land land;

  AddLandParams({required this.land});
}
