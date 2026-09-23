import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/data/models/farm_model.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRemote extends Mock implements FarmRemoteDataSource {}
class _MockSyncEngine extends Mock implements SyncEngine {}

FarmModel _farm(int id, {bool isDefault = false, FarmRole role = FarmRole.owner}) {
  return FarmModel(
    id: id, name: 'Farm $id', location: '', fiscalYearStartMonth: 1,
    ownerUserId: 1, successorUserId: null, maxMembers: 5,
    role: role, memberCount: 1, isDefault: isDefault,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRemote remote;
  late _MockSyncEngine syncEngine;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    remote = _MockRemote();
    syncEngine = _MockSyncEngine();
    when(() => syncEngine.syncNow()).thenAnswer((_) async {});
  });

  test('LoadFarms emits FarmLoaded from cache when farms are already '
      'cached', () async {
    await FarmStorageService.saveFarms([_farm(1, isDefault: true)], defaultFarmId: 1);
    final bloc = FarmBloc(remote: remote, triggerSync: syncEngine.syncNow);
    addTearDown(bloc.close);

    bloc.add(LoadFarms());
    final state = await bloc.stream.firstWhere((s) => s is FarmLoaded);

    expect((state as FarmLoaded).farms, hasLength(1));
    expect(state.currentFarmId, 1);
    expect(state.currentRole, FarmRole.owner);
    verifyNever(() => remote.listFarms());
  });

  test('LoadFarms falls back to a live refresh when nothing is cached '
      '(spec §8 rollout case)', () async {
    when(() => remote.listFarms())
        .thenAnswer((_) async => [_farm(9, isDefault: true, role: FarmRole.manager)]);
    final bloc = FarmBloc(remote: remote, triggerSync: syncEngine.syncNow);
    addTearDown(bloc.close);

    bloc.add(LoadFarms());
    final state = await bloc.stream.firstWhere((s) => s is FarmLoaded);

    expect((state as FarmLoaded).currentFarmId, 9);
    expect(state.currentRole, FarmRole.manager);
    verify(() => remote.listFarms()).called(1);
    expect(await FarmStorageService.getDefaultFarmId(), 9);
  });

  test('RefreshFarms updates storage and state from a live fetch',
      () async {
    await FarmStorageService.saveFarms([_farm(1, isDefault: true)], defaultFarmId: 1);
    when(() => remote.listFarms()).thenAnswer(
      (_) async => [_farm(1, isDefault: true), _farm(2, role: FarmRole.worker)],
    );
    final bloc = FarmBloc(remote: remote, triggerSync: syncEngine.syncNow);
    addTearDown(bloc.close);

    bloc.add(RefreshFarms());
    final state = await bloc.stream.firstWhere(
      (s) => s is FarmLoaded && s.farms.length == 2,
    );

    expect((state as FarmLoaded).farms.map((f) => f.id), [1, 2]);
  });

  test('RefreshFarms failure keeps the last known good state rather than '
      'emitting FarmError over it', () async {
    await FarmStorageService.saveFarms([_farm(1, isDefault: true)], defaultFarmId: 1);
    when(() => remote.listFarms()).thenThrow(Exception('offline'));
    final bloc = FarmBloc(remote: remote, triggerSync: syncEngine.syncNow);
    addTearDown(bloc.close);

    bloc.add(LoadFarms());
    await bloc.stream.firstWhere((s) => s is FarmLoaded);

    bloc.add(RefreshFarms());
    // Give the failed refresh a chance to (not) emit.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(bloc.state, isA<FarmLoaded>());
  });

  test('SwitchFarm persists the selection, updates state, and kicks a '
      'sync pass', () async {
    await FarmStorageService.saveFarms(
      [_farm(1, isDefault: true), _farm(2, role: FarmRole.worker)],
      defaultFarmId: 1,
    );
    final bloc = FarmBloc(remote: remote, triggerSync: syncEngine.syncNow);
    addTearDown(bloc.close);
    bloc.add(LoadFarms());
    await bloc.stream.firstWhere((s) => s is FarmLoaded);

    bloc.add(const SwitchFarm(2));
    final state = await bloc.stream.firstWhere(
      (s) => s is FarmLoaded && s.currentFarmId == 2,
    );

    expect((state as FarmLoaded).currentRole, FarmRole.worker);
    expect(await FarmStorageService.getCurrentFarmId(), 2);
    verify(() => syncEngine.syncNow()).called(1);
  });
}
