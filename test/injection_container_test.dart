import 'package:drift/native.dart';
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/repositories/land_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Smoke test for Task 10's DI wiring: `di.init()` (given an in-memory
/// `AppDatabase` — the real `AppDatabase.open()` needs `path_provider`,
/// unavailable off a real platform channel here) must resolve every
/// offline-first singleton without throwing, and `LandRepository` must
/// still resolve to a `LandRepositoryImpl` — the flag (`OfflineConfig
/// .enabled`, off by default) is what decides whether it behaves
/// local-first, not whether it can be constructed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => GetIt.instance.reset());

  test(
    'di.init(database: ...) resolves the offline-first singletons and '
    'LandRepository without throwing',
    () async {
      // `DioClientFactory.create` (built while resolving `Dio` for
      // `DeletionsDataSource`) reads `AppConfig.baseUrl`, which needs the
      // environment initialized first — `main()` does this before
      // `di.init()` in production.
      AppConfig.initialize();
      await di.init(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
      );

      expect(di.sl<AppDatabase>(), isA<AppDatabase>());
      expect(di.sl<OutboxDao>(), isA<OutboxDao>());
      expect(di.sl<LandLocalDataSource>(), isA<LandLocalDataSource>());
      expect(di.sl<SyncEngine>(), isA<SyncEngine>());

      final landRepository = di.sl<LandRepository>();
      expect(landRepository, isA<LandRepositoryImpl>());
    },
  );
}
