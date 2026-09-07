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
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
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
import 'package:farm_tracker/features/farm/data/datasources/activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/dashboard_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/harvest_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_activity_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/herd_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/infrastructure_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/plant_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/revenue_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/season_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/repositories/activity_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/analysis_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_type_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/cost_category_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/dashboard_repository_impl.dart';
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
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/dashboard_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_activity_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
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
/// `await di.init()` call is unaffected: it still registers the real
/// `AppDatabase` via the async-singleton branch below. That database wraps a
/// `LazyDatabase`, so constructing it opens NO file — the SQLite file is
/// opened lazily on the first query, which (flag-off) never happens. So
/// `await sl.allReady()` guarantees the singleton is CONSTRUCTED before
/// `runApp`, not that any file I/O has occurred — a deliberate part of the
/// dark-ship: init adds no startup file I/O and no new failure mode.
/// (Do NOT "fix" this to open the file eagerly — that would reintroduce
/// flag-off startup I/O.)
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
    ..registerFactory(() => LandBloc(repository: sl()))
    ..registerFactory(() => PlantBloc(repository: sl()))
    ..registerFactory(() => SeasonBloc(repository: sl()))
    ..registerFactory(() => ActivityBloc(repository: sl()))
    ..registerFactory(() => InputBloc(repository: sl()))
    ..registerFactory(() => HarvestBloc(repository: sl()))
    ..registerFactory(() => AnimalTypeBloc(repository: sl()))
    ..registerFactory(() => HerdBloc(repository: sl()))
    ..registerFactory(() => AnimalBloc(repository: sl()))
    ..registerFactory(() => HerdActivityBloc(repository: sl()))
    ..registerFactory(() => InfrastructureBloc(repository: sl()))
    ..registerFactory(() => AnalysisBloc(repository: sl()))
    ..registerFactory(() => DashboardBloc(repository: sl()))
    ..registerFactory(() => RevenueBloc(repository: sl()))
    ..registerFactory(() => CostCategoryBloc(repository: sl()))
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
      () => PlantRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<SeasonRepository>(
      () => SeasonRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<ActivityRepository>(
      () => ActivityRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<InputRepository>(
      () => InputRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<HarvestRepository>(
      () => HarvestRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<AnimalRepository>(
      () => AnimalRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<AnimalTypeRepository>(
      () => AnimalTypeRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<HerdRepository>(
      () => HerdRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<HerdActivityRepository>(
      () => HerdActivityRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<InfrastructureRepository>(
      () => InfrastructureRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<AnalysisRepository>(
      () => AnalysisRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(remoteDataSource: sl()),
    )
    ..registerLazySingleton<RevenueRepository>(
      () => RevenueRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
    )
    ..registerLazySingleton<CostCategoryRepository>(
      () => CostCategoryRepositoryImpl(
        remoteDataSource: sl(),
        local: sl(),
        outbox: sl(),
        sync: sl(),
      ),
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
    ..registerLazySingleton<DashboardRemoteDataSource>(
      () => DashboardRemoteDataSourceImpl(dio: sl()),
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
    ..registerLazySingleton(() => PlantLocalDataSource(sl()))
    ..registerLazySingleton(() => SeasonLocalDataSource(sl()))
    ..registerLazySingleton(() => AnimalLocalDataSource(sl()))
    ..registerLazySingleton(() => HarvestLocalDataSource(sl()))
    ..registerLazySingleton(() => InputLocalDataSource(sl()))
    ..registerLazySingleton(() => ActivityLocalDataSource(sl()))
    ..registerLazySingleton(() => AnimalTypeLocalDataSource(sl()))
    ..registerLazySingleton(() => HerdLocalDataSource(sl()))
    ..registerLazySingleton(() => InfrastructureLocalDataSource(sl()))
    ..registerLazySingleton(() => RevenueLocalDataSource(sl()))
    ..registerLazySingleton(() => CostCategoryLocalDataSource(sl()))
    ..registerLazySingleton(() => HerdActivityLocalDataSource(sl()))
    ..registerLazySingleton(ConnectivityService.new)
    ..registerLazySingleton(() => LandSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => PlantSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => SeasonSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => AnimalSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => HarvestSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => InputSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => ActivitySyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => AnimalTypeSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => HerdSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(
      () => InfrastructureSyncer(remote: sl(), local: sl()),
    )
    ..registerLazySingleton(() => RevenueSyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(() => CostCategorySyncer(remote: sl(), local: sl()))
    ..registerLazySingleton(
      () => HerdActivitySyncer(remote: sl(), local: sl()),
    );

  // All 13 offline-mirrored entities' local mirrors, keyed by the same
  // `entity` tag used in the outbox/tombstone feed. Shared by BOTH
  // `DeletionsDataSource` (applies inbound tombstones) and `SyncEngine` (the
  // FK resolver's prior-pass fallback) — one registry, one place to add a
  // 14th entity.
  //
  // `late` is load-bearing: `AppDatabase` (which every `*LocalDataSource`
  // depends on) is a `registerSingletonAsync` not yet READY at this point in
  // `init()` — only after the `await sl.allReady()` below. An eager `final`
  // here would force every `sl<...LocalDataSource>()` call immediately,
  // before the database is ready, and crash. `late` defers this map's first
  // build to whenever `DeletionsDataSource`/`SyncEngine` is first actually
  // resolved (well after `allReady`), while still computing it exactly once
  // and sharing that one instance between both registrations below.
  late final syncStores = <String, LocalSyncStore<SyncableModel>>{
    'land': sl<LandLocalDataSource>(),
    'plant': sl<PlantLocalDataSource>(),
    'season': sl<SeasonLocalDataSource>(),
    'animal': sl<AnimalLocalDataSource>(),
    'harvest': sl<HarvestLocalDataSource>(),
    'input': sl<InputLocalDataSource>(),
    'activity': sl<ActivityLocalDataSource>(),
    'animal_type': sl<AnimalTypeLocalDataSource>(),
    'herd': sl<HerdLocalDataSource>(),
    'infrastructure': sl<InfrastructureLocalDataSource>(),
    'revenue': sl<RevenueLocalDataSource>(),
    'cost_category': sl<CostCategoryLocalDataSource>(),
    'herd_activity': sl<HerdActivityLocalDataSource>(),
  };

  sl
    ..registerLazySingleton(
      () => DeletionsDataSource(dio: sl(), stores: syncStores),
    )
    ..registerLazySingleton(
      () => SyncEngine(
        outbox: sl(),
        syncers: [
          sl<LandSyncer>(),
          sl<PlantSyncer>(),
          sl<SeasonSyncer>(),
          sl<AnimalSyncer>(),
          sl<HarvestSyncer>(),
          sl<InputSyncer>(),
          sl<ActivitySyncer>(),
          sl<AnimalTypeSyncer>(),
          sl<HerdSyncer>(),
          sl<InfrastructureSyncer>(),
          sl<RevenueSyncer>(),
          sl<CostCategorySyncer>(),
          sl<HerdActivitySyncer>(),
        ],
        cursors: sl(),
        connectivity: sl(),
        deletions: sl<DeletionsDataSource>(),
        fkStores: syncStores,
        // Pre-flip hardening: gate every sync pass on an authenticated
        // session so a pre-login launch/resume/connectivity-regain trigger
        // never hits a protected endpoint, gets a 401, and forces an
        // unwarranted logout (see `SyncEngine`'s "Authenticated gate" doc).
        // isLoggedIn() (not a bare token-presence check) is expiry-aware: a
        // token stored >24h ago is treated as unauthenticated, not just an
        // absent one, so a stale session can't slip a pass through either.
        isAuthenticated: () => UserStorageService.isLoggedIn(),
        // Pre-flip hardening: surface an otherwise-swallowed non-transient
        // pass failure (see SyncEngine's "Error logging" doc) via the app
        // logger instead of silently ending the pass in `SyncPhase.error`.
        onError: (error, stackTrace) =>
            appLogger.logError('SyncEngine', error, stackTrace),
      ),
    );

  // Blocks until the async `AppDatabase` singleton is CONSTRUCTED (when
  // `database` wasn't supplied) - callers of `await di.init()` are guaranteed
  // the DB object exists before proceeding (e.g. `main()` before `runApp`).
  // Its `LazyDatabase` opens the SQLite file lazily on the first query, so
  // this does NOT force a file open at startup (flag-off, no query ever runs)
  // - keeping init free of startup file I/O for the dark ship.
  await sl.allReady();
}
