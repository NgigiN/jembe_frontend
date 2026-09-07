import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

abstract class HarvestState extends Equatable {
  const HarvestState({this.harvests = const []});
  final List<Harvest> harvests;

  @override
  List<Object?> get props => [harvests];
}

class HarvestInitial extends HarvestState {}

class HarvestLoading extends HarvestState {
  const HarvestLoading({super.harvests});
}

class HarvestLoaded extends HarvestState {
  const HarvestLoaded({
    required super.harvests,
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  });
  final String? successMessage;

  /// Online infinite-scroll (P3-02a): `false` only when the last page came
  /// back full (== `kOnlineListPageSize`), i.e. another page may exist.
  /// Defaults to `true` so the offline stream path and the Add/Update/Delete
  /// handlers (which don't page) never trigger a load-more.
  final bool hasReachedMax;

  /// The server id to page from next (`?cursor=`), i.e. the last item's id.
  /// `null` once [hasReachedMax] or when the list is empty.
  final int? nextCursor;

  @override
  List<Object?> get props => [
    harvests,
    successMessage,
    hasReachedMax,
    nextCursor,
  ];
}

class HarvestError extends HarvestState {
  const HarvestError(this.message, {super.harvests});
  final String message;

  @override
  List<Object> get props => [message, harvests];
}
