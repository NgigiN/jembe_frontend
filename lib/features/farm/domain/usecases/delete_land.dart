import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';

class DeleteLand implements UseCase<void, DeleteLandParams> {
  DeleteLand(this.repository);
  final LandRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteLandParams params) async {
    return repository.deleteLand(params.id);
  }
}

class DeleteLandParams {
  DeleteLandParams({required this.id});
  final String id;
}
