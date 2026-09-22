import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/models/user_model.dart';
import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:farm_tracker/features/farms/data/models/farm_model.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';

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

      // Farm identity (V2 sub-project 3): parse and persist the farms this
      // user belongs to, plus their backend default farm.
      final rawFarms = response['farms'] as List<dynamic>? ?? const [];
      final farms = rawFarms
          .map((json) => FarmModel.fromJson(json as Map<String, dynamic>))
          .toList();
      final defaultFarmIdRaw = response['defaultFarmId'];
      final defaultFarmId =
          defaultFarmIdRaw is num ? defaultFarmIdRaw.toInt() : null;
      await FarmStorageService.saveFarms(farms, defaultFarmId: defaultFarmId);

      return Right(userModel);
    } on NetworkException catch (_) {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
