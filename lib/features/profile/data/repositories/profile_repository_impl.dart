import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.remoteDataSource});
  final ProfileRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      final userModel = await remoteDataSource.getProfile();
      return Right(userModel);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
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
    required int fiscalYearStartMonth,
    String? farmName,
    String? location,
  }) async {
    try {
      await remoteDataSource.updateProfile(
        firstName: firstName,
        lastName: lastName,
        fiscalYearStartMonth: fiscalYearStartMonth,
        farmName: farmName,
        location: location,
      );
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await remoteDataSource.deleteAccount();
      return const Right(null);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure('An unexpected error occurred'));
    }
  }
}
