import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';

abstract class HerdState extends Equatable {
  const HerdState({this.herds = const []});
  final List<Herd> herds;

  @override
  List<Object?> get props => [herds];
}

class HerdInitial extends HerdState {}

class HerdLoading extends HerdState {
  const HerdLoading({super.herds});
}

class HerdLoaded extends HerdState {
  const HerdLoaded(
    List<Herd> herds, {
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  }) : super(herds: herds);
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
  List<Object?> get props => [herds, successMessage, hasReachedMax, nextCursor];
}

class HerdError extends HerdState {

  const HerdError(this.message, {super.herds});
  final String message;

  @override
  List<Object?> get props => [message, herds];
}

