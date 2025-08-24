import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/land_repository.dart';

class DeleteLand implements UseCase<void, DeleteLandParams> {
  final LandRepository repository;

  DeleteLand(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteLandParams params) async {
    return await repository.deleteLand(params.id);
  }
}

class DeleteLandParams {
  final String id;

  DeleteLandParams({required this.id});
}
