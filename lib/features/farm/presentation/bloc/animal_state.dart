import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalState extends Equatable {
  const AnimalState({this.animals = const []});
  final List<Animal> animals;

  @override
  List<Object?> get props => [animals];
}

class AnimalInitial extends AnimalState {}

class AnimalLoading extends AnimalState {
  const AnimalLoading({super.animals});
}

class AnimalLoaded extends AnimalState {
  const AnimalLoaded({
    required super.animals,
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
  List<Object?> get props => [animals, successMessage, hasReachedMax, nextCursor];
}

class AnimalError extends AnimalState {
  const AnimalError(this.message, {super.animals});
  final String message;

  @override
  List<Object> get props => [message, animals];
}
