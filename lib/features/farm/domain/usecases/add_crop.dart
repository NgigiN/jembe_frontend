import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/crop.dart';
import '../repositories/crop_repository.dart';

class AddCrop implements UseCase<Crop, AddCropParams> {
  final CropRepository repository;

  AddCrop(this.repository);

  @override
  Future<Either<Failure, Crop>> call(AddCropParams params) async {
    return await repository.addCrop(params.crop);
  }
}

class AddCropParams {
  final Crop crop;

  AddCropParams({required this.crop});
}
