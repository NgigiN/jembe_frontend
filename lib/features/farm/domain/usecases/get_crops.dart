import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/crop.dart';
import '../repositories/crop_repository.dart';

class GetCrops implements UseCase<List<Crop>, NoParams> {
  final CropRepository repository;

  GetCrops(this.repository);

  @override
  Future<Either<Failure, List<Crop>>> call(NoParams params) async {
    return await repository.getCrops();
  }
}
