import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/crop.dart';
import '../repositories/crop_repository.dart';

class UpdateCrop implements UseCase<Crop, UpdateCropParams> {
  final CropRepository repository;

  UpdateCrop(this.repository);

  @override
  Future<Either<Failure, Crop>> call(UpdateCropParams params) async {
    return await repository.updateCrop(params.crop);
  }
}

class UpdateCropParams {
  final Crop crop;

  UpdateCropParams({required this.crop});
}
