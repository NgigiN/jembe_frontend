import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/crop.dart';

abstract class CropRepository {
  Future<Either<Failure, List<Crop>>> getCrops();
  Future<Either<Failure, Crop>> addCrop(Crop crop);
  Future<Either<Failure, Crop>> updateCrop(Crop crop);
  Future<Either<Failure, void>> deleteCrop(String id);
}
