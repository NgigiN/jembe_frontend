import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';

abstract class PlantState extends Equatable {
  const PlantState({this.plants = const []});
  final List<Plant> plants;

  @override
  List<Object?> get props => [plants];
}

class PlantInitial extends PlantState {}

class PlantLoading extends PlantState {
  const PlantLoading({super.plants});
}

class PlantLoaded extends PlantState {
  const PlantLoaded({
    required super.plants,
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
  List<Object?> get props => [plants, successMessage, hasReachedMax, nextCursor];
}

class PlantError extends PlantState {
  const PlantError(this.message, {super.plants});
  final String message;

  @override
  List<Object> get props => [message, plants];
}
