import 'dart:async';

import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_harvests.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_harvests.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Internal-only event: never dispatched from outside this file. The
/// `WatchHarvestsEvent` handler below listens to `watchHarvests(seasonId:)`
/// and funnels every emission back through the bloc's own event queue via
/// `add(...)` instead of calling `emit` directly from the stream callback —
/// the standard bloc pattern for turning an external stream into state,
/// since `emit` is only valid while its owning `on<...>` handler is still
/// active.
class _HarvestsUpdated extends HarvestEvent {
  _HarvestsUpdated(this.harvests);
  final List<Harvest> harvests;

  @override
  List<Object> get props => [harvests];
}

/// Internal-only event: the `WatchHarvestsEvent` handler's stream
/// subscription routes its `onError` through here (same reasoning as
/// `_HarvestsUpdated` — `emit` is only valid inside an active `on<...>`
/// handler, not from a raw stream callback). Non-fatal: it surfaces a
/// `HarvestError` over the last known `harvests` snapshot rather than
/// crashing the bloc or dropping reactivity — the subscription is NOT
/// cancelled, so a later emission (if the underlying stream keeps going)
/// still comes through.
class _HarvestsWatchFailed extends HarvestEvent {
  _HarvestsWatchFailed(this.message);
  final String message;

  @override
  List<Object> get props => [message];
}

class HarvestBloc extends Bloc<HarvestEvent, HarvestState> {
  HarvestBloc({
    required this.getHarvests,
    required this.addHarvest,
    required this.updateHarvest,
    required this.deleteHarvest,
    required this.watchHarvests,
  }) : super(HarvestInitial()) {
    on<GetHarvestsEvent>(_onGetHarvests);
    on<WatchHarvestsEvent>(_onWatchHarvests);
    on<_HarvestsUpdated>((event, emit) {
      emit(HarvestLoaded(harvests: event.harvests));
    });
    on<_HarvestsWatchFailed>((event, emit) {
      emit(HarvestError(event.message, harvests: state.harvests));
    });
    on<AddHarvestEvent>(_onAddHarvest);
    on<UpdateHarvestEvent>(_onUpdateHarvest);
    on<DeleteHarvestEvent>(_onDeleteHarvest);
  }

  final GetHarvests getHarvests;
  final AddHarvest addHarvest;
  final UpdateHarvest updateHarvest;
  final DeleteHarvest deleteHarvest;
  final WatchHarvests watchHarvests;

  StreamSubscription<List<Harvest>>? _harvestsSubscription;
  bool _watchStarted = false;

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

  // Synchronous handler, no `await` before the guard: dispatching
  // WatchHarvestsEvent twice in quick succession (e.g. initState +
  // pull-to-refresh) must never race and orphan a live subscription — the
  // guard makes the second (and every subsequent) dispatch a pure no-op
  // instead.
  void _onWatchHarvests(
    WatchHarvestsEvent event,
    Emitter<HarvestState> emit,
  ) {
    if (_watchStarted) return;
    _watchStarted = true;
    _harvestsSubscription = watchHarvests(seasonId: event.seasonId).listen(
      (harvests) => add(_HarvestsUpdated(harvests)),
      onError: (Object error, StackTrace stackTrace) {
        appLogger.logError('HarvestBloc.watchHarvests', error, stackTrace);
        add(_HarvestsWatchFailed('Live sync interrupted. Pull to refresh.'));
      },
      onDone: () {
        appLogger.info(
          LogCategory.farm,
          'HarvestBloc.watchHarvests stream completed',
        );
      },
    );
  }

  Future<void> _onAddHarvest(
    AddHarvestEvent event,
    Emitter<HarvestState> emit,
  ) async {
    if (OfflineConfig.enabled) {
      final result = await addHarvest(AddHarvestParams(harvest: event.harvest));
      result.fold(
        (failure) => emit(HarvestError(
          resolveFailureMessage(failure, 'Failed to add harvest'),
          harvests: state.harvests,
        )),
        (_) => emit(
          HarvestLoaded(harvests: state.harvests, successMessage: 'Harvest recorded'),
        ),
      );
      return;
    }

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
    if (OfflineConfig.enabled) {
      final result =
          await updateHarvest(UpdateHarvestParams(harvest: event.harvest));
      result.fold(
        (failure) => emit(HarvestError(
          resolveFailureMessage(failure, 'Failed to update harvest'),
          harvests: state.harvests,
        )),
        (_) => emit(
          HarvestLoaded(harvests: state.harvests, successMessage: 'Harvest updated'),
        ),
      );
      return;
    }

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
    if (OfflineConfig.enabled) {
      final result = await deleteHarvest(DeleteHarvestParams(id: event.id));
      result.fold(
        (failure) => emit(HarvestError(
          resolveFailureMessage(failure, 'Failed to delete harvest'),
          harvests: state.harvests,
        )),
        (_) => emit(
          HarvestLoaded(harvests: state.harvests, successMessage: 'Harvest deleted'),
        ),
      );
      return;
    }

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

  @override
  Future<void> close() async {
    await _harvestsSubscription?.cancel();
    return super.close();
  }
}
