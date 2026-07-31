import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animal_types.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal_type.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';

class AnimalTypeBloc extends Bloc<AnimalTypeEvent, AnimalTypeState> {

  AnimalTypeBloc({
    required this.getAnimalTypes,
    required this.addAnimalType,
    required this.updateAnimalType,
    required this.deleteAnimalType,
  }) : super(AnimalTypeInitial()) {
    on<GetAnimalTypesEvent>(_onGetAnimalTypes);
    on<AddAnimalTypeEvent>(_onAddAnimalType);
    on<UpdateAnimalTypeEvent>(_onUpdateAnimalType);
    on<DeleteAnimalTypeEvent>(_onDeleteAnimalType);
  }
  final GetAnimalTypes getAnimalTypes;
  final AddAnimalType addAnimalType;
  final UpdateAnimalType updateAnimalType;
  final DeleteAnimalType deleteAnimalType;

  Future<void> _onGetAnimalTypes(
    GetAnimalTypesEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    emit(const AnimalTypeLoading());
    final result = await getAnimalTypes(NoParams());
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to load animal types'),
      )),
      (animalTypes) => emit(AnimalTypeLoaded(animalTypes)),
    );
  }

  Future<void> _onAddAnimalType(
    AddAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    final currentAnimalTypes = state.animalTypes;

    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await addAnimalType(event.name, event.notes, event.userId);
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to add animal type'),
        animalTypes: currentAnimalTypes,
      )),
      (animalType) {
        final updatedAnimalTypes = List<AnimalType>.from(currentAnimalTypes)
          ..add(animalType);
        emit(AnimalTypeLoaded(updatedAnimalTypes, successMessage: 'Animal type added'));
      },
    );
  }

  Future<void> _onUpdateAnimalType(
    UpdateAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    final currentAnimalTypes = state.animalTypes;
    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await updateAnimalType(event.id, event.name, event.notes);
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to update animal type'),
        animalTypes: currentAnimalTypes,
      )),
      (updatedAnimalType) {
        final updatedAnimalTypes = currentAnimalTypes.map((type) {
          return type.id == updatedAnimalType.id ? updatedAnimalType : type;
        }).toList();
        emit(AnimalTypeLoaded(updatedAnimalTypes, successMessage: 'Animal type updated'));
      },
    );
  }

  Future<void> _onDeleteAnimalType(
    DeleteAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    final currentAnimalTypes = state.animalTypes;
    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await deleteAnimalType(event.id);
    result.fold(
      (failure) => emit(AnimalTypeError(
        resolveFailureMessage(failure, 'Failed to delete animal type'),
        animalTypes: currentAnimalTypes,
      )),
      (_) {
        final updatedAnimalTypes =
            currentAnimalTypes.where((type) => type.id != event.id).toList();
        emit(AnimalTypeLoaded(updatedAnimalTypes, successMessage: 'Animal type deleted'));
      },
    );
  }
}
