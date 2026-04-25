import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/models/user_model.dart';
import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.remoteDataSource});
  final AuthRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, User>> googleSignIn(String idToken) async {
    try {
      final response = await remoteDataSource.googleSignIn(idToken);
      final userModel = response['user'] as UserModel;
      final token = response['token'] as String;
      final record = response['record'] as Map<String, dynamic>;

      // Save user data to shared preferences
      final userStorage = UserStorageModel.fromAuthResponse(record, token);
      await UserStorageService.saveUserData(userStorage);

      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
