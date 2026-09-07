import 'package:equatable/equatable.dart';

abstract class AnimalTypeEvent extends Equatable {
  const AnimalTypeEvent();

  @override
  List<Object?> get props => [];
}

class GetAnimalTypesEvent extends AnimalTypeEvent {}

/// Flag-ON only: subscribes (or re-subscribes) `AnimalTypeBloc` to
/// `repository.watchAnimalTypes()`. Every subsequent stream emission is
/// turned into an `AnimalTypeLoaded(...)` state — see `AnimalTypeBloc`'s
/// internal `_AnimalTypesUpdated` event for how.
class WatchAnimalTypesEvent extends AnimalTypeEvent {}

/// Flag-OFF (online) only: fetches the NEXT page of animal types using the
/// current `AnimalTypeLoaded.nextCursor` and APPENDS it. Ignored when the
/// loaded state has already reached max or a load-more is in flight. The
/// offline (`watchAnimalTypes`) path never dispatches this.
class LoadMoreAnimalTypesEvent extends AnimalTypeEvent {}

class AddAnimalTypeEvent extends AnimalTypeEvent {
  const AddAnimalTypeEvent(this.name, this.notes, this.userId);
  final String name;
  final String? notes;
  final String userId;

  @override
  List<Object?> get props => [name, notes, userId];
}

class UpdateAnimalTypeEvent extends AnimalTypeEvent {
  const UpdateAnimalTypeEvent(this.id, this.name, this.notes);
  final String id;
  final String name;
  final String? notes;

  @override
  List<Object?> get props => [id, name, notes];
}

class DeleteAnimalTypeEvent extends AnimalTypeEvent {
  const DeleteAnimalTypeEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
