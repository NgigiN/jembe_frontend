import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/auth/presentation/pages/splash_page.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockDio extends Mock implements Dio {}

/// Always-online fake — never exercised here (both spied-on methods are
/// overridden below before any real connectivity/outbox/cursor logic runs),
/// just satisfies [SyncEngine]'s constructor.
class _NoOpConnectivity implements ConnectivityService {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onlineChanges => const Stream.empty();
}

/// A real [SyncEngine] with its two side-effecting entry points overridden
/// to record calls (in order) instead of running the real push/pull/backoff
/// machinery — lets a test assert exactly what `applyOfflineFlagSideEffects`
/// invoked, and in what order, without a fake Dio/server harness.
class _SpySyncEngine extends SyncEngine {
  _SpySyncEngine(AppDatabase db)
    : super(
        outbox: OutboxDao(db),
        syncers: const [],
        cursors: SyncCursorDao(db),
        connectivity: _NoOpConnectivity(),
      );

  final List<String> calls = [];

  @override
  void start() => calls.add('start');

  @override
  Future<void> syncNow() async => calls.add('syncNow');
}

void main() {
  setUpAll(() => registerFallbackValue(CheckExistingLoginEvent()));

  late MockDio mockDio;

  // SplashPage.initState reads AnalyticsService from the service locator
  // before the login-check delay, so it must be registered for the page
  // to build at all.
  setUp(() {
    mockDio = MockDio();
    // A proper no-op stub: previously this registered a bare, unstubbed
    // MockDio, so flush()'s internal try/catch silently swallowed the
    // resulting mocktail error and this test never actually exercised (or
    // asserted on) real analytics behavior. Stubbing a success response
    // lets the test verify the real POST instead.
    when(
      () => mockDio.post<void>(any(), data: any(named: 'data')),
    ).thenAnswer(
      (_) async =>
          Response<void>(requestOptions: RequestOptions(), statusCode: 201),
    );
    sl.registerLazySingleton<AnalyticsService>(
      () => AnalyticsService(dio: mockDio),
    );
  });

  tearDown(() {
    sl.unregister<AnalyticsService>();
  });

  testWidgets('dispatches CheckExistingLoginEvent within 300ms', (tester) async {
    final authBloc = MockAuthBloc();
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: AuthInitial());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(value: authBloc, child: const SplashPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => authBloc.add(any(that: isA<CheckExistingLoginEvent>()))).called(1);

    // SplashPage.initState() calls AnalyticsService.track(), which schedules
    // a real 30s flush Timer. flutter_test's AutomatedTestWidgetsFlutterBinding
    // asserts no Timer is left pending when a test ends, so drain it
    // explicitly here rather than waiting.
    await sl<AnalyticsService>().flush();

    final captured = verify(
      () => mockDio.post<void>(
        '/api/v1/events',
        data: captureAny(named: 'data'),
      ),
    ).captured;
    final body = captured.single as Map<String, dynamic>;
    final events = body['events'] as List;
    expect(events, hasLength(1));
    expect(events.single['name'], 'app_open');
  });

  group('decideOfflineFlagChange', () {
    test('no-op when the parsed value already matches the current flag', () {
      final same = decideOfflineFlagChange(
        parsedValue: false,
        currentValue: false,
      );
      expect(same.changed, isFalse);
      expect(same.newlyEnabled, isFalse);

      final sameOn = decideOfflineFlagChange(
        parsedValue: true,
        currentValue: true,
      );
      expect(sameOn.changed, isFalse);
      expect(sameOn.newlyEnabled, isFalse);
    });

    test('off-to-on transition is a change AND newly enabled', () {
      final decision = decideOfflineFlagChange(
        parsedValue: true,
        currentValue: false,
      );
      expect(decision.changed, isTrue);
      expect(decision.newlyEnabled, isTrue);
    });

    test('on-to-off transition (rollback) is a change but NOT newly enabled', () {
      final decision = decideOfflineFlagChange(
        parsedValue: false,
        currentValue: true,
      );
      expect(decision.changed, isTrue);
      expect(decision.newlyEnabled, isFalse);
    });
  });

  group('applyOfflineFlagSideEffects', () {
    late AppDatabase db;
    late _SpySyncEngine engine;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      engine = _SpySyncEngine(db);
    });

    tearDown(() async {
      engine.dispose();
      await db.close();
    });

    test(
      'a newly-enabled (off-to-on) decision calls start() THEN syncNow() '
      '- mirroring the main() launch sequence, so the very first session '
      'after the server flips the flag gets the connectivity-regained '
      'trigger wired, not just an immediate one-shot sync',
      () async {
        applyOfflineFlagSideEffects(
          const OfflineFlagDecision(changed: true, newlyEnabled: true),
          engine,
        );
        await pumpEventQueue();

        expect(engine.calls, ['start', 'syncNow']);
      },
    );

    test(
      'a rollback (on-to-off) decision calls neither start() nor syncNow()',
      () async {
        applyOfflineFlagSideEffects(
          const OfflineFlagDecision(changed: true, newlyEnabled: false),
          engine,
        );
        await pumpEventQueue();

        expect(engine.calls, isEmpty);
      },
    );

    test('an unchanged decision calls neither start() nor syncNow()', () async {
      applyOfflineFlagSideEffects(
        const OfflineFlagDecision(changed: false, newlyEnabled: false),
        engine,
      );
      await pumpEventQueue();

      expect(engine.calls, isEmpty);
    });
  });
}
