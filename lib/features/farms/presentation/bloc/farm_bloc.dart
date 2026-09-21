import 'dart:async';

import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FarmBloc extends Bloc<FarmEvent, FarmState> {
  FarmBloc({required this.remote, required this.syncEngine}) : super(FarmInitial()) {
    on<LoadFarms>((event, emit) async {
      final cached = await FarmStorageService.getFarms();
      if (cached.isNotEmpty) {
        await _emitFromStorage(emit);
        return;
      }
      // Nothing cached yet — an already-logged-in device upgrading to this
      // release for the first time (spec §8). The session token is still
      // valid, so a live fetch works without forcing a re-login.
      await _refresh(emit, allowErrorState: true);
    });

    on<RefreshFarms>((event, emit) async {
      // A background refresh (app resume/launch) must never blank out
      // already-good cached state on failure.
      await _refresh(emit, allowErrorState: state is! FarmLoaded);
    });

    on<SwitchFarm>((event, emit) async {
      await FarmStorageService.setCurrentFarmId(event.farmId);
      await _emitFromStorage(emit);
      unawaited(syncEngine.syncNow());
    });
  }

  final FarmRemoteDataSource remote;
  final SyncEngine syncEngine;

  Future<void> _emitFromStorage(Emitter<FarmState> emit) async {
    final farms = await FarmStorageService.getFarms();
    final currentFarmId = await FarmStorageService.getCurrentFarmId();
    final currentRole = await FarmStorageService.getCurrentRole();
    emit(FarmLoaded(farms: farms, currentFarmId: currentFarmId, currentRole: currentRole));
  }

  Future<void> _refresh(Emitter<FarmState> emit, {required bool allowErrorState}) async {
    try {
      final farms = await remote.listFarms();
      Farm? defaultFarm;
      for (final farm in farms) {
        if (farm.isDefault) {
          defaultFarm = farm;
          break;
        }
      }
      await FarmStorageService.saveFarms(farms, defaultFarmId: defaultFarm?.id);
      await _emitFromStorage(emit);
    } on Object catch (_) {
      if (allowErrorState) {
        emit(const FarmError('Unable to load your farms. Pull to refresh to try again.'));
      }
      // Else: keep whatever FarmLoaded state is already current — a failed
      // background refresh must not blank out good cached data.
    }
  }
}
