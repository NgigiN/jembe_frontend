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
    this.hasReachedMax = true,
    this.nextCursor,
  });
  final String? successMessage;

  /// The id of the land just created by an `AddLandEvent` that produced
  /// this state (`successMessage == 'Land added'`), threaded through
  /// explicitly rather than inferred from list position — flag-ON's
  /// `lands` here is the pre-write snapshot (the reactive stream updates
  /// it separately/asynchronously), so `lands.last` is not reliable.
  /// Null for every other state (including other success messages).
  final String? addedLandId;

  /// Online infinite-scroll (P3-02a): `false` only when the last page came
  /// back full (== `kOnlineListPageSize`), i.e. another page may exist.
  /// Defaults to `true` so the offline stream path (and the Add/Update/
  /// Delete handlers, which don't page) never trigger a load-more.
  final bool hasReachedMax;

  /// The server id to page from next (`?cursor=`), i.e. the last item's id.
  /// `null` once [hasReachedMax] or when the list is empty.
  final int? nextCursor;

  @override
  List<Object?> get props => [
    lands,
    successMessage,
    addedLandId,
    hasReachedMax,
    nextCursor,
  ];
}

class LandError extends LandState {
  const LandError(this.message, {super.lands});
  final String message;

  @override
  List<Object> get props => [message, lands];
}
