import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';

class ChangePassword implements UseCase<void, ChangePasswordParams> {
  ChangePassword(this.repository);
  final ProfileRepository repository;

  @override
  Future<Either<Failure, void>> call(ChangePasswordParams params) async {
    return repository.changePassword(
      oldPassword: params.oldPassword,
      newPassword: params.newPassword,
    );
  }
}

class ChangePasswordParams extends Equatable {
  const ChangePasswordParams({
    required this.oldPassword,
    required this.newPassword,
  });
  final String oldPassword;
  final String newPassword;

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
