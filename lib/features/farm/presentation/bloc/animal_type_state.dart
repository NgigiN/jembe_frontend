import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';

abstract class AnimalTypeState extends Equatable {
  const AnimalTypeState({this.animalTypes = const []});
  final List<AnimalType> animalTypes;

  @override
  List<Object?> get props => [animalTypes];
}

class AnimalTypeInitial extends AnimalTypeState {}

class AnimalTypeLoading extends AnimalTypeState {
  const AnimalTypeLoading({super.animalTypes});
}

class AnimalTypeLoaded extends AnimalTypeState {
  const AnimalTypeLoaded(
    List<AnimalType> animalTypes, {
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  }) : super(animalTypes: animalTypes);
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
      [animalTypes, successMessage, hasReachedMax, nextCursor];
}

class AnimalTypeError extends AnimalTypeState {

  const AnimalTypeError(this.message, {super.animalTypes});
  final String message;

  @override
  List<Object?> get props => [message, animalTypes];
}

