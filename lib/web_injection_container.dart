// lib/web_injection_container.dart
//
// Lean DI for the web console (spec 2026-09-22-v2-web-console-design.md §3): a
// SEPARATE GetIt instance from lib/injection_container.dart's mobile one,
// registering only what the console needs. Deliberately never imports
// app_database.dart, sync_engine.dart, offline_repository.dart, or any of the
// 13 entity CRUD blocs/repositories — those pull in package:sqlite3's
// dart:ffi bindings, which cannot compile for web at all (confirmed by a
// real build spike, not a hypothesis).
//
// GoogleSignInService is deliberately NOT registered (and not imported)
// here. Its only constructor, GoogleSignInService._(), is private — it
// cannot be instantiated outside its own file, so `GoogleSignInService.new`
// does not exist/compile. It's also never DI-consumed anywhere: AuthBloc
// calls its static `GoogleSignInService.ensureInitialized()` method
// directly (see lib/features/auth/presentation/bloc/auth_bloc.dart), never
// through GetIt. See lib/injection_container.dart (mobile) for
// confirmation — it doesn't register GoogleSignInService either.
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:farm_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:farm_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:farm_tracker/features/auth/domain/usecases/google_sign_in_usecase.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/farm/data/datasources/analysis_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/dashboard_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/repositories/analysis_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/repositories/dashboard_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/repositories/analysis_repository.dart';
import 'package:farm_tracker/features/farm/domain/repositories/dashboard_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:get_it/get_it.dart';

final GetIt webSl = GetIt.asNewInstance();

Future<void> initWebDependencies() async {
  webSl
    ..registerLazySingleton(SessionExpiryNotifier.new)
    ..registerLazySingleton<CacheStore>(MemCacheStore.new)
    ..registerLazySingleton<Dio>(
      () => DioClientFactory.create(cacheStore: webSl(), sessionExpiry: webSl()),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(dio: webSl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: webSl()),
    )
    ..registerLazySingleton(() => GoogleSignInUseCase(webSl()))
    ..registerLazySingleton(() => AuthBloc(googleSignInUseCase: webSl(), cleanCache: () => webSl<CacheStore>().clean()))
    ..registerLazySingleton<FarmRemoteDataSource>(
      () => FarmRemoteDataSourceImpl(dio: webSl()),
    )
    ..registerLazySingleton(
      () => FarmBloc(remote: webSl(), triggerSync: () async {}),
    )
    ..registerLazySingleton<DashboardRemoteDataSource>(
      () => DashboardRemoteDataSourceImpl(dio: webSl()),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(remoteDataSource: webSl()),
    )
    ..registerFactory(() => DashboardBloc(repository: webSl()))
    ..registerLazySingleton<AnalysisRemoteDataSource>(
      () => AnalysisRemoteDataSourceImpl(dio: webSl()),
    )
    ..registerLazySingleton<AnalysisRepository>(
      () => AnalysisRepositoryImpl(remoteDataSource: webSl()),
    )
    ..registerFactory(() => AnalysisBloc(repository: webSl()))
    ..registerLazySingleton(ThemeBloc.new);
}
