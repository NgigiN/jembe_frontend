import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/offline/widgets/offline_banner.dart';
import 'package:farm_tracker/core/offline/widgets/sync_status_indicator.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockSyncEngine extends Mock implements SyncEngine {}

const _fakeUser = User(
  id: 'user-1',
  email: 'a@example.com',
  firstName: 'A',
  lastName: 'B',
  farmName: 'Farm',
  location: 'Somewhere',
  pictureUrl: '',
);

/// A minimal shell harness: a real [GoRouter] with a single [ShellRoute]
/// wrapping [LandingPage], mirroring the app's own router wiring (P5b lifts
/// the offline indicators into that shell) closely enough for
/// `GoRouterState.of(context)` and `context.go` to resolve, without pulling
/// in the full app router/DI graph.
Widget _harness(AuthBloc authBloc) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Center(child: Text('tab content')),
          ),
        ],
      ),
    ],
  );

  return BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late MockAuthBloc authBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(_fakeUser),
    );
  });

  testWidgets(
    'flag OFF: both indicators are mounted in the shell but render '
    'byte-for-byte identical to today (no offline/sync chrome visible, tab '
    'content still shows)',
    (tester) async {
      OfflineConfig.enabled = false;
      await tester.pumpWidget(_harness(authBloc));
      await tester.pumpAndSettle();

      // Present in the tree (lifted into the shell)...
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.byType(SyncStatusIndicator), findsOneWidget);

      // ...but self-hidden, so nothing new is visible flag-off.
      expect(
        find.text("You're offline — changes will sync when you reconnect"),
        findsNothing,
      );
      expect(find.byTooltip('Sync now'), findsNothing);
      expect(find.text('tab content'), findsOneWidget);
    },
  );

  group('flag ON', () {
    late StreamController<bool> onlineController;
    late StreamController<SyncStatus> statusController;
    late MockConnectivityService connectivityService;
    late MockSyncEngine syncEngine;

    setUp(() {
      onlineController = StreamController<bool>.broadcast();
      statusController = StreamController<SyncStatus>.broadcast();
      connectivityService = MockConnectivityService();
      syncEngine = MockSyncEngine();
      when(
        () => connectivityService.onlineChanges,
      ).thenAnswer((_) => onlineController.stream);
      when(
        () => syncEngine.statusStream,
      ).thenAnswer((_) => statusController.stream);
      when(
        () => syncEngine.status,
      ).thenReturn(const SyncStatus(phase: SyncPhase.idle));

      GetIt.instance
        ..registerSingleton<ConnectivityService>(connectivityService)
        ..registerSingleton<SyncEngine>(syncEngine);
      OfflineConfig.enabled = true;
    });

    tearDown(() async {
      OfflineConfig.enabled = false;
      await onlineController.close();
      await statusController.close();
      await GetIt.instance.reset();
    });

    testWidgets(
      'shows the offline banner and sync status above the active tab, '
      'in the shell (not per-page)',
      (tester) async {
        await tester.pumpWidget(_harness(authBloc));
        await tester.pump();

        onlineController.add(false);
        statusController.add(
          const SyncStatus(phase: SyncPhase.idle, pendingCount: 2),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text("You're offline — changes will sync when you reconnect"),
          findsOneWidget,
        );
        expect(find.text('2 pending'), findsOneWidget);
        expect(find.text('tab content'), findsOneWidget);
      },
    );
  });
}
