import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';
import '../models/user_storage_model.dart';
import '../services/user_storage_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      final response = await remoteDataSource.login(email, password);
      final userModel = response['user'] as UserModel;
      final token = response['token'] as String;
      final record = response['record'] as Map<String, dynamic>;

      // Save user data to shared preferences
      final userStorage = UserStorageModel.fromAuthResponse(record, token);
      await UserStorageService.saveUserData(userStorage);

      return Right(userModel);
    } on ServerException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, User>> signup(
    String email,
    String password,
    String name,
    String farmName,
    String location,
  ) async {
    try {
      final userModel = await remoteDataSource.signup(
        email,
        password,
        name,
        farmName,
        location,
      );
      return Right(userModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
