import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';

abstract class LandState extends Equatable {
  const LandState({this.lands = const []});
  final List<Land> lands;

  @override
  List<Object?> get props => [lands];
}

class LandInitial extends LandState {}

class LandLoading extends LandState {
  const LandLoading({super.lands});
}

class LandLoaded extends LandState {
  const LandLoaded({
    required super.lands,
    this.successMessage,
    this.addedLandId,
  });
  final String? successMessage;

  /// The id of the land just created by an `AddLandEvent` that produced
  /// this state (`successMessage == 'Land added'`), threaded through
  /// explicitly rather than inferred from list position — flag-ON's
  /// `lands` here is the pre-write snapshot (the reactive stream updates
  /// it separately/asynchronously), so `lands.last` is not reliable.
  /// Null for every other state (including other success messages).
  final String? addedLandId;

  @override
  List<Object?> get props => [lands, successMessage, addedLandId];
}

class LandError extends LandState {
  const LandError(this.message, {super.lands});
  final String message;

  @override
  List<Object> get props => [message, lands];
}
