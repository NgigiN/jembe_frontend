import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/profile/domain/usecases/get_profile.dart';
import 'package:farm_tracker/features/profile/domain/usecases/update_profile.dart';
import 'package:farm_tracker/features/profile/domain/usecases/change_password.dart';
import 'package:farm_tracker/features/profile/domain/usecases/delete_account.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    required this.getProfile,
    required this.updateProfile,
    required this.changePassword,
    required this.deleteAccount,
  }) : super(ProfileInitial()) {
    on<FetchProfileEvent>(_onFetchProfile);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<ChangePasswordEvent>(_onChangePassword);
    on<DeleteAccountEvent>(_onDeleteAccount);
  }
  final GetProfile getProfile;
  final UpdateProfile updateProfile;
  final ChangePassword changePassword;
  final DeleteAccount deleteAccount;

  Future<void> _onFetchProfile(
    FetchProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final failureOrUser = await getProfile(NoParams());

    failureOrUser.fold(
      (failure) => emit(ProfileError(message: _mapFailureToMessage(failure))),
      (user) => emit(ProfileLoaded(user: user)),
    );
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final failureOrSuccess = await updateProfile(
      UpdateProfileParams(
        firstName: event.firstName,
        lastName: event.lastName,
        fiscalYearStartMonth: event.fiscalYearStartMonth,
        farmName: event.farmName,
        location: event.location,
      ),
    );

    failureOrSuccess.fold(
      (failure) => emit(ProfileError(message: _mapFailureToMessage(failure))),
      (_) =>
          emit(const ProfileOperationSuccess('Profile updated successfully')),
    );
  }

  Future<void> _onChangePassword(
    ChangePasswordEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final failureOrSuccess = await changePassword(
      ChangePasswordParams(
        oldPassword: event.oldPassword,
        newPassword: event.newPassword,
      ),
    );

    failureOrSuccess.fold(
      (failure) => emit(ProfileError(message: _mapFailureToMessage(failure))),
      (_) =>
          emit(const ProfileOperationSuccess('Password changed successfully')),
    );
  }

  Future<void> _onDeleteAccount(
    DeleteAccountEvent event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());
    final failureOrSuccess = await deleteAccount(NoParams());

    failureOrSuccess.fold(
      (failure) => emit(ProfileError(message: _mapFailureToMessage(failure))),
      (_) => emit(AccountDeleted()),
    );
  }

  String _mapFailureToMessage(Failure failure) =>
      resolveFailureMessage(failure, 'Something went wrong. Please try again.');
}
