import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_herd.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_herd.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_herds.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_herd.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';

class HerdBloc extends Bloc<HerdEvent, HerdState> {

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
  final GetHerds getHerds;
  final AddHerd addHerd;
  final UpdateHerd updateHerd;
  final DeleteHerd deleteHerd;

  Future<void> _onGetHerds(
    GetHerdsEvent event,
    Emitter<HerdState> emit,
  ) async {
    emit(const HerdLoading());
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
    final currentHerds = state is HerdLoaded ? (state as HerdLoaded).herds : <Herd>[];

    emit(HerdLoading(herds: currentHerds));
    final result = await addHerd(
      event.name,
      event.animalTypeId,
      event.location,
      event.userId,
      event.initialHeadCount,
    );
    result.fold(
      (failure) => emit(HerdError('Failed to add herd', herds: currentHerds)),
      (herd) {
        final updatedHerds = List<Herd>.from(currentHerds)..add(herd);
        emit(HerdLoaded(updatedHerds));
      },
    );
  }

  Future<void> _onUpdateHerd(
    UpdateHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    final currentHerds = state.herds;
    emit(HerdLoading(herds: currentHerds));
    final result = await updateHerd(
      event.id,
      event.name,
      event.animalTypeId,
      event.location,
      event.initialHeadCount,
    );
    result.fold(
      (failure) => emit(HerdError('Failed to update herd', herds: currentHerds)),
      (updatedHerd) {
        final updatedHerds = currentHerds.map((herd) {
          return herd.id == updatedHerd.id ? updatedHerd : herd;
        }).toList();
        emit(HerdLoaded(updatedHerds));
      },
    );
  }

  Future<void> _onDeleteHerd(
    DeleteHerdEvent event,
    Emitter<HerdState> emit,
  ) async {
    final currentHerds = state.herds;
    emit(HerdLoading(herds: currentHerds));
    final result = await deleteHerd(event.id);
    result.fold(
      (failure) => emit(HerdError('Failed to delete herd', herds: currentHerds)),
      (_) {
        final updatedHerds =
            currentHerds.where((herd) => herd.id != event.id).toList();
        emit(HerdLoaded(updatedHerds));
      },
    );
  }
}
