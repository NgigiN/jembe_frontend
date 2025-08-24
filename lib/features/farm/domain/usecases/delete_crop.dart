import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/crop_repository.dart';

class DeleteCrop implements UseCase<void, DeleteCropParams> {
  final CropRepository repository;

  DeleteCrop(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteCropParams params) async {
    return await repository.deleteCrop(params.id);
  }
}

class DeleteCropParams {
  final String id;

  DeleteCropParams({required this.id});
}
