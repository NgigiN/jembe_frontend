import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';

class UpdateProfile implements UseCase<void, UpdateProfileParams> {
  UpdateProfile(this.repository);
  final ProfileRepository repository;

  @override
  Future<Either<Failure, void>> call(UpdateProfileParams params) async {
    return repository.updateProfile(
      firstName: params.firstName,
      lastName: params.lastName,
      farmName: params.farmName,
      location: params.location,
      fiscalYearStartMonth: params.fiscalYearStartMonth,
    );
  }
}

class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({
    required this.firstName,
    required this.lastName,
    required this.fiscalYearStartMonth,
    this.farmName,
    this.location,
  });

  final String firstName;
  final String lastName;
  final int fiscalYearStartMonth;
  final String? farmName;
  final String? location;

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    fiscalYearStartMonth,
    farmName,
    location,
  ];
}
