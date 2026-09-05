import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:farm_tracker/core/sync/deletions_data_source.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:farm_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:farm_tracker/features/auth/domain/usecases/google_sign_in_usecase.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/content/data/datasources/content_local_data_source.dart';
import 'package:farm_tracker/features/content/data/datasources/question_remote_data_source.dart';
import 'package:farm_tracker/features/content/data/repositories/content_repository_impl.dart';
import 'package:farm_tracker/features/content/data/repositories/question_repository_impl.dart';
import 'package:farm_tracker/features/content/domain/repositories/content_repository.dart';
import 'package:farm_tracker/features/content/domain/repositories/question_repository.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_bloc.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/repositories/activity_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/analysis_repository_impl.dart';
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
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
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
import 'package:farm_tracker/features/farm/domain/usecases/add_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_cost_category.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_herd.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_herd_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_cost_category.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_herd.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_activities.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animal_types.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animals.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_annual_cost_summary.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_cost_breakdown.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_cost_categories.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_harvests.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_herds.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_inputs.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_lands.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_plants.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenue_by_id.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenues.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_seasons.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_total_costs_by_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_activity.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal_type.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_harvest.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_herd.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_input.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_land.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_plant.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/watch_lands.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/harvest_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/plant_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:farm_tracker/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:farm_tracker/features/profile/domain/repositories/profile_repository.dart';
import 'package:farm_tracker/features/profile/domain/usecases/delete_account.dart';
import 'package:farm_tracker/features/profile/domain/usecases/get_profile.dart';
import 'package:farm_tracker/features/profile/domain/usecases/update_profile.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

/// Wires the DI container.
///
/// [database] lets tests substitute an in-memory [AppDatabase] (registered
/// as a plain, already-ready singleton) instead of opening the real file —
/// `AppDatabase.open()` needs `path_provider`, which isn't available off a
/// real device/platform channel in unit tests. `main.dart`'s no-arg
/// `await di.init()` call is unaffected: it still opens the real file via
/// the async-singleton branch below, and `await sl.allReady()` at the end
/// of this function guarantees that file is open before `runApp`.
Future<void> init({AppDatabase? database}) async {
  // Initialize logging
  appLogger.initialize();

  // Offline-first local database (Task 10) — see the [database] doc above.
  if (database != null) {
    sl.registerSingleton<AppDatabase>(database);
  } else {
    sl.registerSingletonAsync<AppDatabase>(() async => AppDatabase.open());
  }

  // Bloc
  sl
    // AuthBloc is a singleton (not a factory like the other blocs): it must
    // be the exact same instance the SessionExpiryNotifier listener in
    // main.dart dispatches LogoutEvent onto and the one BlocProvider hands
    // to the widget tree, or a forced logout would land on an orphan bloc
    // the UI never sees.
    ..registerLazySingleton(() => AuthBloc(googleSignInUseCase: sl()))
    // Feature-specific blocs (preferred)
    ..registerFactory(
      () => LandBloc(
        getLands: sl(),
        addLand: sl(),
        updateLand: sl(),
        deleteLand: sl(),
        watchLands: sl(),
      ),
    )
    ..registerFactory(
      () => PlantBloc(
        getPlants: sl(),
        addPlant: sl(),
        updatePlant: sl(),
        deletePlant: sl(),
      ),
    )
    ..registerFactory(
      () => SeasonBloc(
        getSeasons: sl(),
        addSeason: sl(),
        updateSeason: sl(),
        deleteSeason: sl(),
      ),
    )
    ..registerFactory(
      () => ActivityBloc(
        getActivities: sl(),
        addActivity: sl(),
        updateActivity: sl(),
        deleteActivity: sl(),
      ),
    )
    ..registerFactory(
      () => InputBloc(
        getInputs: sl(),
        addInput: sl(),
        updateInput: sl(),
        deleteInput: sl(),
      ),
    )
    ..registerFactory(
      () => HarvestBloc(
        getHarvests: sl(),
        addHarvest: sl(),
        updateHarvest: sl(),
        deleteHarvest: sl(),
      ),
    )
    ..registerFactory(
      () => AnimalTypeBloc(
        getAnimalTypes: sl(),
        addAnimalType: sl(),
        updateAnimalType: sl(),
        deleteAnimalType: sl(),
      ),
    )
    ..registerFactory(
      () => HerdBloc(
        getHerds: sl(),
        addHerd: sl(),
        updateHerd: sl(),
        deleteHerd: sl(),
      ),
    )
    ..registerFactory(
      () => AnimalBloc(
        getAnimals: sl(),
        addAnimal: sl(),
        updateAnimal: sl(),
        deleteAnimal: sl(),
      ),
    )
    ..registerFactory(() => HerdActivityBloc(addHerdActivity: sl()))
    ..registerFactory(
      () => InfrastructureBloc(
        getInfrastructure: sl(),
        addInfrastructure: sl(),
        updateInfrastructure: sl(),
        deleteInfrastructure: sl(),
      ),
    )
    ..registerFactory(
      () => AnalysisBloc(
        getTotalCostsBySeason: sl(),
        getCostBreakdown: sl(),
        getAnnualCostSummary: sl(),
      ),
    )
    ..registerFactory(
      () => RevenueBloc(
        getRevenues: sl(),
        getRevenueById: sl(),
        addRevenue: sl(),
        updateRevenue: sl(),
        deleteRevenue: sl(),
      ),
    )
    ..registerFactory(
      () => CostCategoryBloc(
        getCostCategories: sl(),
        addCostCategory: sl(),
        deleteCostCategory: sl(),
      ),
    )
    ..registerFactory(
      () => ProfileBloc(
        getProfile: sl(),
        updateProfile: sl(),
        deleteAccount: sl(),
      ),
    )
    ..registerFactory(() => ContentBloc(repository: sl()))
    ..registerFactory(() => QuestionBloc(repository: sl()))
    // Use Cases
    ..registerLazySingleton(() => GoogleSignInUseCase(sl()))
    ..registerLazySingleton(() => GetLands(sl()))
    ..registerLazySingleton(() => AddLand(sl()))
    ..registerLazySingleton(() => UpdateLand(sl()))
    ..registerLazySingleton(() => DeleteLand(sl()))
    ..registerLazySingleton(() => WatchLands(sl()))
    ..registerLazySingleton(() => GetPlants(sl()))
    ..registerLazySingleton(() => AddPlant(sl()))
    ..registerLazySingleton(() => UpdatePlant(sl()))
    ..registerLazySingleton(() => DeletePlant(sl()))
    ..registerLazySingleton(() => GetSeasons(sl()))
    ..registerLazySingleton(() => AddSeason(sl()))
    ..registerLazySingleton(() => UpdateSeason(sl()))
    ..registerLazySingleton(() => DeleteSeason(sl()))
    ..registerLazySingleton(() => GetActivities(sl()))
    ..registerLazySingleton(() => AddActivity(sl()))
    ..registerLazySingleton(() => UpdateActivity(sl()))
    ..registerLazySingleton(() => DeleteActivity(sl()))
    ..registerLazySingleton(() => GetInputs(sl()))
    ..registerLazySingleton(() => AddInput(sl()))
    ..registerLazySingleton(() => UpdateInput(sl()))
    ..registerLazySingleton(() => DeleteInput(sl()))
    ..registerLazySingleton(() => GetHarvests(sl()))
    ..registerLazySingleton(() => AddHarvest(sl()))
    ..registerLazySingleton(() => UpdateHarvest(sl()))
    ..registerLazySingleton(() => DeleteHarvest(sl()))
    ..registerLazySingleton(() => GetAnimals(sl()))
    ..registerLazySingleton(() => AddAnimal(sl()))
    ..registerLazySingleton(() => UpdateAnimal(sl()))
    ..registerLazySingleton(() => DeleteAnimal(sl()))
    ..registerLazySingleton(() => GetAnimalTypes(sl()))
    ..registerLazySingleton(() => AddAnimalType(sl()))
    ..registerLazySingleton(() => UpdateAnimalType(sl()))
    ..registerLazySingleton(() => DeleteAnimalType(sl()))
    ..registerLazySingleton(() => GetHerds(sl()))
    ..registerLazySingleton(() => AddHerd(sl()))
    ..registerLazySingleton(() => UpdateHerd(sl()))
    ..registerLazySingleton(() => DeleteHerd(sl()))
    ..registerLazySingleton(() => AddHerdActivity(sl()))
    ..registerLazySingleton(() => GetInfrastructure(sl()))
    ..registerLazySingleton(() => AddInfrastructure(sl()))
    ..registerLazySingleton(() => UpdateInfrastructure(sl()))
    ..registerLazySingleton(() => DeleteInfrastructure(sl()))
    ..registerLazySingleton(() => GetTotalCostsBySeason(sl()))
    ..registerLazySingleton(() => GetCostBreakdown(sl()))
    ..registerLazySingleton(() => GetAnnualCostSummary(sl()))
    ..registerLazySingleton(() => GetRevenues(sl()))
    ..registerLazySingleton(() => GetRevenueById(sl()))
    ..registerLazySingleton(() => AddRevenue(sl()))
    ..registerLazySingleton(() => UpdateRevenue(sl()))
    ..registerLazySingleton(() => DeleteRevenue(sl()))
    ..registerLazySingleton(() => GetCostCategories(sl()))
    ..registerLazySingleton(() => AddCostCategory(sl()))
    ..registerLazySingleton(() => DeleteCostCategory(sl()))
    ..registerLazySingleton(() => GetProfile(sl()))
    ..registerLazySingleton(() => UpdateProfile(sl()))
    ..registerLazySingleton(() => DeleteAccount(sl()))
    // Repositories
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl()),
    )
    // Injecting the offline collaborators here is dark-safe: `OfflineConfig
    // .enabled` defaults false, so `LandRepositoryImpl._offlineFirst` is
    // false and every method still takes its old remote-only path — see
    // `land_repository_impl.dart`'s class docs (rule zero for this rollout).
    ..registerLazySingleton<LandRepository>(
      () => LandRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<PlantRepository>(
      () => PlantRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<SeasonRepository>(
      () => SeasonRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<ActivityRepository>(
      () => ActivityRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<InputRepository>(
      () => InputRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<HarvestRepository>(
      () => HarvestRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<AnimalRepository>(
      () => AnimalRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<AnimalTypeRepository>(
      () => AnimalTypeRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<HerdRepository>(
      () => HerdRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<HerdActivityRepository>(
      () => HerdActivityRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<InfrastructureRepository>(
      () => InfrastructureRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<AnalysisRepository>(
      () => AnalysisRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<RevenueRepository>(
      () => RevenueRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<CostCategoryRepository>(
      () => CostCategoryRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<ContentRepository>(
      () => ContentRepositoryImpl(localDataSource: sl()),
    )
    ..registerLazySingleton<QuestionRepository>(
      () => QuestionRepositoryImpl(remoteDataSource: sl()),
    )
    // Data Sources
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<LandRemoteDataSource>(
      () => LandRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<PlantRemoteDataSource>(
      () => PlantRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<SeasonRemoteDataSource>(
      () => SeasonRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<ActivityRemoteDataSource>(
      () => ActivityRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<InputRemoteDataSource>(
      () => InputRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<HarvestRemoteDataSource>(
      () => HarvestRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<AnimalRemoteDataSource>(
      () => AnimalRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<AnimalTypeRemoteDataSource>(
      () => AnimalTypeRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<HerdRemoteDataSource>(
      () => HerdRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<HerdActivityRemoteDataSource>(
      () => HerdActivityRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<InfrastructureRemoteDataSource>(
      () => InfrastructureRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<AnalysisRemoteDataSource>(
      () => AnalysisRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<RevenueRemoteDataSource>(
      () => RevenueRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<CostCategoryRemoteDataSource>(
      () => CostCategoryRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton<ContentLocalDataSource>(
      ContentLocalDataSourceImpl.new,
    )
    ..registerLazySingleton<QuestionRemoteDataSource>(
      () => QuestionRemoteDataSourceImpl(dio: sl()),
    )
    ..registerLazySingleton(() => AnalyticsService(dio: sl()))
    ..registerLazySingleton(SoundService.new)
    // Network resilience (must be registered before Dio - the factory
    // closure below pulls them from sl()).
    ..registerLazySingleton(SessionExpiryNotifier.new)
    ..registerLazySingleton<CacheStore>(MemCacheStore.new)
    // External - Dio client (preferred for new code)
    ..registerLazySingleton<Dio>(
      () => DioClientFactory.create(cacheStore: sl(), sessionExpiry: sl()),
    )
    // Offline-first sync infra (Task 10) - built here but dark-shipped: with
    // `OfflineConfig.enabled == false` (the default) nothing in `main.dart`
    // ever calls `SyncEngine.start()`/`syncNow()`, and `LandRepositoryImpl`
    // never touches these collaborators either. Depends on `AppDatabase`
    // (registered above) and `Dio` (registered just above, for
    // `DeletionsDataSource`).
    ..registerLazySingleton(() => OutboxDao(sl()))
    ..registerLazySingleton(() => SyncCursorDao(sl()))
    ..registerLazySingleton(() => LandLocalDataSource(sl()))
    ..registerLazySingleton(ConnectivityService.new)
    ..registerLazySingleton(() => LandSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(
      () => DeletionsDataSource(dio: sl(), landLocal: sl()),
    )
    ..registerLazySingleton(
      () => SyncEngine(
        outbox: sl(),
        syncers: [sl<LandSyncer>()],
        cursors: sl(),
        connectivity: sl(),
        deletions: sl<DeletionsDataSource>(),
      ),
    );

  // Blocks until the async `AppDatabase` singleton (real file open, when
  // `database` wasn't supplied) has completed - callers of `await di.init()`
  // are guaranteed a fully-open DB before proceeding (e.g. `main()` before
  // `runApp`).
  await sl.allReady();
}
