import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';

abstract class SeasonState extends Equatable {
  const SeasonState({this.seasons = const []});
  final List<Season> seasons;

  @override
  List<Object?> get props => [seasons];
}

class SeasonInitial extends SeasonState {}

class SeasonLoading extends SeasonState {
  const SeasonLoading({super.seasons});
}

class SeasonLoaded extends SeasonState {
  const SeasonLoaded({
    required super.seasons,
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  });
  final String? successMessage;

  /// Online infinite-scroll (P3-02a): `false` only when the last page came
  /// back full (== `kOnlineListPageSize`), i.e. another page may exist.
  /// Defaults to `true` so the offline stream path (and the Add/Update/
  /// Delete handlers, which don't page) never trigger a load-more.
  final bool hasReachedMax;

  /// The server id to page from next (`?cursor=`), i.e. the last item's id.
  /// `null` once [hasReachedMax] or when the list is empty.
  final int? nextCursor;

  @override
  List<Object?> get props =>
      [seasons, successMessage, hasReachedMax, nextCursor];
}

class SeasonError extends SeasonState {
  const SeasonError(this.message, {super.seasons});
  final String message;

  @override
  List<Object> get props => [message, seasons];
}
