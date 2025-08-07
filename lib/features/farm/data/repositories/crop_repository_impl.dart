import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/crop.dart';
import '../../domain/repositories/crop_repository.dart';
import '../datasources/crop_remote_data_source.dart';
import '../models/crop_model.dart';

class CropRepositoryImpl implements CropRepository {
  final CropRemoteDataSource remoteDataSource;

  CropRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Crop>>> getCrops() async {
    try {
      final crops = await remoteDataSource.getCrops();
      return Right(crops);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Crop>> addCrop(Crop crop) async {
    try {
      // Use the create factory method to convert Crop entity to CropModel
      final cropModel = CropModel.create(
        userId: crop.userId,
        name: crop.name,
        variety: crop.variety,
      );

      final result = await remoteDataSource.addCrop(cropModel);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Crop>> updateCrop(Crop crop) async {
    try {
      final cropModel = await remoteDataSource.updateCrop(crop as dynamic);
      return Right(cropModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCrop(String id) async {
    try {
      await remoteDataSource.deleteCrop(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
