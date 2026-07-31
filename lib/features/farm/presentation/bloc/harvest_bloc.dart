import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_harvests.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_harvest.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';

class HarvestBloc extends Bloc<HarvestEvent, HarvestState> {
  HarvestBloc({
    required this.getHarvests,
    required this.addHarvest,
    required this.updateHarvest,
    required this.deleteHarvest,
  }) : super(HarvestInitial()) {
    on<GetHarvestsEvent>(_onGetHarvests);
    on<AddHarvestEvent>(_onAddHarvest);
    on<UpdateHarvestEvent>(_onUpdateHarvest);
    on<DeleteHarvestEvent>(_onDeleteHarvest);
  }

  final GetHarvests getHarvests;
  final AddHarvest addHarvest;
  final UpdateHarvest updateHarvest;
  final DeleteHarvest deleteHarvest;

  Future<void> _onGetHarvests(
    GetHarvestsEvent event,
    Emitter<HarvestState> emit,
  ) async {
    emit(HarvestLoading(harvests: state.harvests));
    final result = await getHarvests(GetHarvestsParams(seasonId: event.seasonId));
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to load harvests'),
        harvests: state.harvests,
      )),
      (harvests) => emit(HarvestLoaded(harvests: harvests)),
    );
  }

  Future<void> _onAddHarvest(
    AddHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    final currentHarvests = state.harvests;
    emit(HarvestLoading(harvests: currentHarvests));
    final result = await addHarvest(AddHarvestParams(harvest: event.harvest));
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to add harvest'),
        harvests: currentHarvests,
      )),
      (harvest) {
        final updated = List<Harvest>.from(currentHarvests)..add(harvest);
        emit(HarvestLoaded(harvests: updated, successMessage: 'Harvest recorded'));
      },
    );
  }

  Future<void> _onUpdateHarvest(
    UpdateHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    final currentHarvests = state.harvests;
    emit(HarvestLoading(harvests: currentHarvests));
    final result =
        await updateHarvest(UpdateHarvestParams(harvest: event.harvest));
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to update harvest'),
        harvests: currentHarvests,
      )),
      (updatedHarvest) {
        final updated = currentHarvests
            .map((harvest) =>
                harvest.id == updatedHarvest.id ? updatedHarvest : harvest)
            .toList();
        emit(HarvestLoaded(harvests: updated, successMessage: 'Harvest updated'));
      },
    );
  }

  Future<void> _onDeleteHarvest(
    DeleteHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    final currentHarvests = state.harvests;
    emit(HarvestLoading(harvests: currentHarvests));
    final result = await deleteHarvest(DeleteHarvestParams(id: event.id));
    result.fold(
      (failure) => emit(HarvestError(
        resolveFailureMessage(failure, 'Failed to delete harvest'),
        harvests: currentHarvests,
      )),
      (_) {
        final updated = currentHarvests
            .where((harvest) => harvest.id != event.id)
            .toList();
        emit(HarvestLoaded(harvests: updated, successMessage: 'Harvest deleted'));
      },
    );
  }
}
