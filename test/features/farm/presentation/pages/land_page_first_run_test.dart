import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

/// The page always renders a [SyncStatusIndicator], which resolves the engine
/// from DI whenever the offline flag is on. Register a quiet stand-in so these
/// tests exercise the subscribe decision, not the sync pipeline.
class _StubConnectivity implements ConnectivityService {
  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
  @override
  Future<bool> isOnline() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubSyncEngine implements SyncEngine {
  @override
  SyncStatus get status => const SyncStatus(phase: SyncPhase.idle);
  @override
  Stream<SyncStatus> get statusStream => const Stream<SyncStatus>.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(LandBloc bloc) => MaterialApp(
  home: BlocProvider<LandBloc>.value(value: bloc, child: const LandPage()),
);

void main() {
  setUpAll(() => registerFallbackValue(GetLandsEvent()));

  setUp(() {
    if (!di.sl.isRegistered<SyncEngine>()) {
      di.sl.registerSingleton<SyncEngine>(_StubSyncEngine());
    }
    if (!di.sl.isRegistered<ConnectivityService>()) {
      di.sl.registerSingleton<ConnectivityService>(_StubConnectivity());
    }
  });

  tearDown(() {
    // The flag is a mutable static — never let it leak into another test.
    OfflineConfig.enabled = false;
    if (di.sl.isRegistered<SyncEngine>()) di.sl.unregister<SyncEngine>();
    if (di.sl.isRegistered<ConnectivityService>()) {
      di.sl.unregister<ConnectivityService>();
    }
  });

  testWidgets(
    'subscribes even when the bloc already holds an EMPTY loaded list',
    (tester) async {
      // The first-run shape that shipped blank screens: a page elsewhere read
      // the local mirror before the first sync finished, leaving the shared
      // bloc holding LandLoaded([]). The old guard treated that as "already
      // loaded" and skipped subscribing, so the page rendered the empty list
      // forever — even though the mirror filled moments later.
      OfflineConfig.enabled = true;
      final bloc = MockLandBloc();
      whenListen(
        bloc,
        const Stream<LandState>.empty(),
        initialState: const LandLoaded(lands: []),
      );

      await tester.pumpWidget(_wrap(bloc));

      verify(() => bloc.add(any(that: isA<WatchLandsEvent>()))).called(1);
    },
  );

  testWidgets('subscribes from a cold start too', (tester) async {
    OfflineConfig.enabled = true;
    final bloc = MockLandBloc();
    whenListen(
      bloc,
      const Stream<LandState>.empty(),
      initialState: LandInitial(),
    );

    await tester.pumpWidget(_wrap(bloc));

    verify(() => bloc.add(any(that: isA<WatchLandsEvent>()))).called(1);
  });

  testWidgets(
    'with the flag off, a loaded bloc is still left alone',
    (tester) async {
      // The online path must keep its original behaviour exactly: no refetch
      // when the bloc already has data, and no subscription either.
      OfflineConfig.enabled = false;
      final bloc = MockLandBloc();
      whenListen(
        bloc,
        const Stream<LandState>.empty(),
        initialState: const LandLoaded(lands: []),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<GetLandsEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchLandsEvent>())));
    },
  );
}
