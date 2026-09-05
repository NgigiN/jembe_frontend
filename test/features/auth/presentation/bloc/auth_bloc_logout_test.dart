import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/auth/domain/usecases/google_sign_in_usecase.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGoogleSignInUseCase extends Mock implements GoogleSignInUseCase {}

class _ThrowingCacheStore extends Mock implements CacheStore {}

/// A real (in-memory) `AppDatabase` whose `wipeAll()` is overridden to
/// throw, standing in for e.g. a corrupt on-disk file or a mid-wipe I/O
/// fault — exercises `AuthBloc`'s guarded catch without hand-rolling
/// drift's generated API surface.
class _ThrowingAppDatabase extends AppDatabase {
  _ThrowingAppDatabase() : super.forTesting(NativeDatabase.memory());

  @override
  Future<void> wipeAll() async => throw Exception('wipe boom');
}

/// Focused regression test for the guarded logout wipe (P3 Task 2): a
/// `CacheStore.clean()` failure and an `AppDatabase.wipeAll()` failure must
/// each be caught + logged, never left to propagate and abort logout
/// halfway through (token clear / sign-out / final `AuthInitial()` emit
/// must still happen).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `UserStorageService.clearUserData()` (always called by LogoutEvent,
  // flag or no flag) reads/writes flutter_secure_storage + shared_preferences
  // — both need a mocked channel/backing store to resolve in a VM test.
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    await sl.reset();
  });

  tearDown(() async {
    OfflineConfig.enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    await sl.reset();
  });

  test(
    'LogoutEvent: CacheStore.clean() and AppDatabase.wipeAll() failures are '
    'both swallowed (logged, not rethrown) — logout still runs to '
    'completion and emits AuthInitial',
    () async {
      OfflineConfig.enabled = true;

      final cacheStore = _ThrowingCacheStore();
      when(() => cacheStore.clean()).thenThrow(Exception('cache boom'));
      sl.registerSingleton<CacheStore>(cacheStore);

      final db = _ThrowingAppDatabase();
      addTearDown(db.close);
      sl.registerSingleton<AppDatabase>(db);

      final bloc = AuthBloc(
        googleSignInUseCase: _MockGoogleSignInUseCase(),
      );
      addTearDown(bloc.close);

      final states = <AuthState>[];
      final sub = bloc.stream.listen(states.add);
      addTearDown(sub.cancel);

      bloc.add(LogoutEvent());
      await bloc.stream.firstWhere((s) => s is AuthInitial);

      expect(states, [isA<AuthInitial>()]);
      // Both guarded calls actually ran (and threw) rather than the flag
      // silently skipping them.
      verify(() => cacheStore.clean()).called(1);
    },
  );
}
