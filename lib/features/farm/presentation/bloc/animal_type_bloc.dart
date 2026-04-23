import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/animal_type.dart';
import '../../domain/usecases/add_animal_type.dart';
import '../../domain/usecases/delete_animal_type.dart';
import '../../domain/usecases/get_animal_types.dart';
import '../../domain/usecases/update_animal_type.dart';
import 'animal_type_event.dart';
import 'animal_type_state.dart';

class AnimalTypeBloc extends Bloc<AnimalTypeEvent, AnimalTypeState> {
  final GetAnimalTypes getAnimalTypes;
  final AddAnimalType addAnimalType;
  final UpdateAnimalType updateAnimalType;
  final DeleteAnimalType deleteAnimalType;

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

  Future<void> _onGetAnimalTypes(
    GetAnimalTypesEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    emit(AnimalTypeLoading());
    final result = await getAnimalTypes(NoParams());
    result.fold(
      (failure) => emit(const AnimalTypeError('Failed to load animal types')),
      (animalTypes) => emit(AnimalTypeLoaded(animalTypes)),
    );
  }

  Future<void> _onAddAnimalType(
    AddAnimalTypeEvent event,
    Emitter<AnimalTypeState> emit,
  ) async {
    final currentAnimalTypes = state is AnimalTypeLoaded
        ? (state as AnimalTypeLoaded).animalTypes
        : <AnimalType>[];

    emit(AnimalTypeLoading(animalTypes: currentAnimalTypes));
    final result = await addAnimalType(event.name, event.notes, event.userId);
    result.fold(
      (failure) => emit(AnimalTypeError('Failed to add animal type', animalTypes: currentAnimalTypes)),
      (animalType) {
        final updatedAnimalTypes = List<AnimalType>.from(currentAnimalTypes)
          ..add(animalType);
        emit(AnimalTypeLoaded(updatedAnimalTypes));
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
      (failure) => emit(AnimalTypeError('Failed to update animal type', animalTypes: currentAnimalTypes)),
      (updatedAnimalType) {
        final updatedAnimalTypes = currentAnimalTypes.map((type) {
          return type.id == updatedAnimalType.id ? updatedAnimalType : type;
        }).toList();
        emit(AnimalTypeLoaded(updatedAnimalTypes));
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
      (failure) => emit(AnimalTypeError('Failed to delete animal type', animalTypes: currentAnimalTypes)),
      (_) {
        final updatedAnimalTypes =
            currentAnimalTypes.where((type) => type.id != event.id).toList();
        emit(AnimalTypeLoaded(updatedAnimalTypes));
      },
    );
  }
}

