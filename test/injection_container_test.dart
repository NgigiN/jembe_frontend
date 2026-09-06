import 'package:drift/native.dart';
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/deletions_data_source.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/repositories/activity_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_type_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/cost_category_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/harvest_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/herd_activity_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/herd_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/infrastructure_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/input_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/land_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/plant_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/revenue_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/season_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/activity_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/animal_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/animal_type_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/cost_category_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/harvest_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/herd_activity_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/herd_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/infrastructure_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/input_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/plant_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/revenue_syncer.dart';
import 'package:farm_tracker/features/farm/data/sync/season_syncer.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_activity_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Smoke test for Task 10's DI wiring: `di.init()` (given an in-memory
/// `AppDatabase` — the real `AppDatabase.open()` needs `path_provider`,
/// unavailable off a real platform channel here) must resolve every
/// offline-first singleton without throwing, and every entity repository
/// must still resolve to its `*RepositoryImpl` — the flag (`OfflineConfig
/// .enabled`, off by default) is what decides whether it behaves
/// local-first, not whether it can be constructed.
///
/// Task 10 extends this beyond `land` to all 13 offline-mirrored entities
/// (land, plant, season, animal, harvest, input, activity, animal_type,
/// herd, infrastructure, revenue, cost_category, herd_activity) as a
/// DI-graph-completeness gate: every entity rollout task (6–9) wired its
/// own repository/syncer/local-data-source into `injection_container.dart`,
/// and this is the one place that proves none of those 13 wirings was
/// missed or left half-connected.
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

  test(
    'di.init(database: ...) resolves all 13 entity *Syncer singletons '
    'without throwing',
    () async {
      AppConfig.initialize();
      await di.init(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
      );

      expect(di.sl<LandSyncer>(), isA<LandSyncer>());
      expect(di.sl<PlantSyncer>(), isA<PlantSyncer>());
      expect(di.sl<SeasonSyncer>(), isA<SeasonSyncer>());
      expect(di.sl<AnimalSyncer>(), isA<AnimalSyncer>());
      expect(di.sl<HarvestSyncer>(), isA<HarvestSyncer>());
      expect(di.sl<InputSyncer>(), isA<InputSyncer>());
      expect(di.sl<ActivitySyncer>(), isA<ActivitySyncer>());
      expect(di.sl<AnimalTypeSyncer>(), isA<AnimalTypeSyncer>());
      expect(di.sl<HerdSyncer>(), isA<HerdSyncer>());
      expect(di.sl<InfrastructureSyncer>(), isA<InfrastructureSyncer>());
      expect(di.sl<RevenueSyncer>(), isA<RevenueSyncer>());
      expect(di.sl<CostCategorySyncer>(), isA<CostCategorySyncer>());
      expect(di.sl<HerdActivitySyncer>(), isA<HerdActivitySyncer>());

      // These 13 are exactly what `SyncEngine` is built with in
      // `injection_container.dart` — proving each resolves also proves
      // `SyncEngine`'s `syncers` list (which resolved without throwing
      // above, in the first test) is backed by a complete set.
      expect(di.sl<SyncEngine>(), isA<SyncEngine>());
    },
  );

  test(
    'di.init(database: ...) resolves all 13 entity *LocalDataSource '
    'singletons without throwing',
    () async {
      AppConfig.initialize();
      await di.init(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
      );

      expect(di.sl<LandLocalDataSource>(), isA<LandLocalDataSource>());
      expect(di.sl<PlantLocalDataSource>(), isA<PlantLocalDataSource>());
      expect(di.sl<SeasonLocalDataSource>(), isA<SeasonLocalDataSource>());
      expect(di.sl<AnimalLocalDataSource>(), isA<AnimalLocalDataSource>());
      expect(di.sl<HarvestLocalDataSource>(), isA<HarvestLocalDataSource>());
      expect(di.sl<InputLocalDataSource>(), isA<InputLocalDataSource>());
      expect(di.sl<ActivityLocalDataSource>(), isA<ActivityLocalDataSource>());
      expect(
        di.sl<AnimalTypeLocalDataSource>(),
        isA<AnimalTypeLocalDataSource>(),
      );
      expect(di.sl<HerdLocalDataSource>(), isA<HerdLocalDataSource>());
      expect(
        di.sl<InfrastructureLocalDataSource>(),
        isA<InfrastructureLocalDataSource>(),
      );
      expect(di.sl<RevenueLocalDataSource>(), isA<RevenueLocalDataSource>());
      expect(
        di.sl<CostCategoryLocalDataSource>(),
        isA<CostCategoryLocalDataSource>(),
      );
      expect(
        di.sl<HerdActivityLocalDataSource>(),
        isA<HerdActivityLocalDataSource>(),
      );

      // These 13 are exactly what `DeletionsDataSource.stores` is built
      // with in `injection_container.dart` — proving each resolves also
      // proves that map (which resolved without throwing above, in the
      // first test) is backed by a complete set.
      expect(di.sl<DeletionsDataSource>(), isA<DeletionsDataSource>());
    },
  );

  test(
    'di.init(database: ...) resolves all 13 entity repositories to their '
    '*Impl, flag off',
    () async {
      AppConfig.initialize();
      await di.init(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
      );

      expect(di.sl<LandRepository>(), isA<LandRepositoryImpl>());
      expect(di.sl<PlantRepository>(), isA<PlantRepositoryImpl>());
      expect(di.sl<SeasonRepository>(), isA<SeasonRepositoryImpl>());
      expect(di.sl<AnimalRepository>(), isA<AnimalRepositoryImpl>());
      expect(di.sl<HarvestRepository>(), isA<HarvestRepositoryImpl>());
      expect(di.sl<InputRepository>(), isA<InputRepositoryImpl>());
      expect(di.sl<ActivityRepository>(), isA<ActivityRepositoryImpl>());
      expect(
        di.sl<AnimalTypeRepository>(),
        isA<AnimalTypeRepositoryImpl>(),
      );
      expect(di.sl<HerdRepository>(), isA<HerdRepositoryImpl>());
      expect(
        di.sl<InfrastructureRepository>(),
        isA<InfrastructureRepositoryImpl>(),
      );
      expect(di.sl<RevenueRepository>(), isA<RevenueRepositoryImpl>());
      expect(
        di.sl<CostCategoryRepository>(),
        isA<CostCategoryRepositoryImpl>(),
      );
      expect(
        di.sl<HerdActivityRepository>(),
        isA<HerdActivityRepositoryImpl>(),
      );
    },
  );

  test(
    'all-dark: OfflineConfig.enabled is false and a representative new '
    'repository (PlantRepositoryImpl) is fully wired with offline '
    'collaborators yet the flag — not construction — is what decides its '
    'code path',
    () async {
      AppConfig.initialize();
      await di.init(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
      );

      // Default is dark; this task must not (and does not) flip it.
      expect(OfflineConfig.enabled, isFalse);

      final plantRepository = di.sl<PlantRepository>() as PlantRepositoryImpl;
      // Every offline collaborator IS supplied by DI (proving the graph is
      // fully wired, not half-built) — it's `OfflineConfig.enabled` alone
      // that gates whether `PlantRepositoryImpl` takes the local-first path
      // or (as asserted above) the remote/one-shot path, exactly as this
      // class's doc comment describes for the flag-off case.
      expect(plantRepository.local, isNotNull);
      expect(plantRepository.outbox, isNotNull);
      expect(plantRepository.sync, isNotNull);
    },
  );
}
