import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animals.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';

class AnimalBloc extends Bloc<AnimalEvent, AnimalState> {
  AnimalBloc({
    required this.getAnimals,
    required this.addAnimal,
    required this.updateAnimal,
    required this.deleteAnimal,
  }) : super(AnimalInitial()) {
    on<GetAnimalsEvent>((event, emit) async {
      emit(const AnimalLoading());
      final result = await getAnimals(NoParams());
      result.fold(
        (failure) => emit(
          AnimalError(resolveFailureMessage(failure, 'Failed to load animals')),
        ),
        (animals) => emit(AnimalLoaded(animals: animals)),
      );
    });

    on<AddAnimalEvent>((event, emit) async {
      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await addAnimal(AddAnimalParams(animal: event.animal));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to add animal'),
          animals: currentAnimals,
        )),
        (animal) {
          final updatedAnimals = List<Animal>.from(currentAnimals)..add(animal);
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal added'));
        },
      );
    });

    on<UpdateAnimalEvent>((event, emit) async {
      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await updateAnimal(UpdateAnimalParams(animal: event.animal));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to update animal'),
          animals: currentAnimals,
        )),
        (updatedAnimal) {
          final updatedAnimals = currentAnimals.map((animal) {
            return animal.id == updatedAnimal.id ? updatedAnimal : animal;
          }).toList();
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal updated'));
        },
      );
    });

    on<DeleteAnimalEvent>((event, emit) async {
      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await deleteAnimal(DeleteAnimalParams(id: event.id));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to delete animal'),
          animals: currentAnimals,
        )),
        (_) {
          final updatedAnimals =
              currentAnimals.where((animal) => animal.id != event.id).toList();
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal deleted'));
        },
      );
    });
  }
  final GetAnimals getAnimals;
  final AddAnimal addAnimal;
  final UpdateAnimal updateAnimal;
  final DeleteAnimal deleteAnimal;
}
