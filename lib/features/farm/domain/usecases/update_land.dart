import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/land.dart';
import '../repositories/farm_repository.dart';

class UpdateLand implements UseCase<Land, UpdateLandParams> {
  final FarmRepository repository;

  UpdateLand(this.repository);

  @override
  Future<Either<Failure, Land>> call(UpdateLandParams params) async {
    return await repository.updateLand(params.id, params.name);
  }
}

class UpdateLandParams {
  final String id;
  final String name;

  UpdateLandParams({required this.id, required this.name});
}
