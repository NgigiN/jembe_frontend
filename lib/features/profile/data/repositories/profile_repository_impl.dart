import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';
import 'package:farm_tracker/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.remoteDataSource});
  final ProfileRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      final userModel = await remoteDataSource.getProfile();
      
      // Update local storage for consistency
      await UserStorageService.updateUserField('first_name', userModel.firstName);
      await UserStorageService.updateUserField('last_name', userModel.lastName);
      await UserStorageService.updateUserField('name', userModel.fullName);
      await UserStorageService.updateUserField('farm_name', userModel.farmName);
      await UserStorageService.updateUserField('location', userModel.location);
      await UserStorageService.updateUserField('picture_url', userModel.pictureUrl);
      
      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile({
    required String firstName,
    required String lastName,
    String? farmName,
    String? location,
  }) async {
    try {
      await remoteDataSource.updateProfile(
        firstName: firstName,
        lastName: lastName,
        farmName: farmName,
        location: location,
      );

      // Update local storage on success
      if (farmName != null) {
        await UserStorageService.updateUserField('farm_name', farmName);
      }
      if (location != null) {
        await UserStorageService.updateUserField('location', location);
      }
      await UserStorageService.updateUserField('name', '$firstName $lastName'.trim());

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await remoteDataSource.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }
}
