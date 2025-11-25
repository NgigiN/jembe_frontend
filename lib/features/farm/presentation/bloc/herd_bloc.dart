import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/add_herd.dart';
import '../../domain/usecases/delete_herd.dart';
import '../../domain/usecases/get_herds.dart';
import '../../domain/usecases/update_herd.dart';
import 'herd_event.dart';
import 'herd_state.dart';

class HerdBloc extends Bloc<HerdEvent, HerdState> {
  final GetHerds getHerds;
  final AddHerd addHerd;
  final UpdateHerd updateHerd;
  final DeleteHerd deleteHerd;

  HerdBloc({
    required this.getHerds,
    required this.addHerd,
    required this.updateHerd,
    required this.deleteHerd,
  }) : super(HerdInitial()) {
    on<GetHerdsEvent>(_onGetHerds);
    on<AddHerdEvent>(_onAddHerd);
    on<UpdateHerdEvent>(_onUpdateHerd);
    on<DeleteHerdEvent>(_onDeleteHerd);
  }

  Future<void> _onGetHerds(
    GetHerdsEvent event,
    Emitter<HerdState> emit,
  ) async {
    emit(HerdLoading());
    final result = await getHerds(NoParams());
    result.fold(
      (failure) => emit(const HerdError('Failed to load herds')),
      (herds) => emit(HerdLoaded(herds)),
    );
  }

  Future<void> _onAddHerd(
    AddHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    emit(HerdLoading());
    final result = await addHerd(event.name, event.animalTypeId, event.location, event.userId);
    await result.fold(
      (failure) async => emit(const HerdError('Failed to add herd')),
      (_) async {
        final getResult = await getHerds(NoParams());
        getResult.fold(
          (failure) => emit(const HerdError('Failed to load herds')),
          (herds) => emit(HerdLoaded(herds)),
        );
      },
    );
  }

  Future<void> _onUpdateHerd(
    UpdateHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    emit(HerdLoading());
    final result = await updateHerd(event.id, event.name, event.animalTypeId, event.location);
    await result.fold(
      (failure) async => emit(const HerdError('Failed to update herd')),
      (_) async {
        final getResult = await getHerds(NoParams());
        getResult.fold(
          (failure) => emit(const HerdError('Failed to load herds')),
          (herds) => emit(HerdLoaded(herds)),
        );
      },
    );
  }

  Future<void> _onDeleteHerd(
    DeleteHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    emit(HerdLoading());
    final result = await deleteHerd(event.id);
    await result.fold(
      (failure) async => emit(const HerdError('Failed to delete herd')),
      (_) async {
        final getResult = await getHerds(NoParams());
        getResult.fold(
          (failure) => emit(const HerdError('Failed to load herds')),
          (herds) => emit(HerdLoaded(herds)),
        );
      },
    );
  }
}

