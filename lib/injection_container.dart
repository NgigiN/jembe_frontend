import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/logging_http_client.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/signup.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/farm/data/datasources/activity_remote_data_source.dart';
import 'features/farm/data/datasources/plant_remote_data_source.dart';
import 'features/farm/data/datasources/farm_remote_data_source.dart';
import 'features/farm/data/datasources/input_remote_data_source.dart';
import 'features/farm/data/datasources/land_remote_data_source.dart';
import 'features/farm/data/datasources/season_remote_data_source.dart';
import 'features/farm/data/datasources/analysis_remote_data_source.dart';
import 'features/farm/data/repositories/activity_repository_impl.dart';
import 'features/farm/data/repositories/analysis_repository_impl.dart';
import 'features/farm/data/repositories/plant_repository_impl.dart';
import 'features/farm/data/services/farm_data_service.dart';
import 'features/farm/data/repositories/farm_repository_impl.dart';
import 'features/farm/data/repositories/input_repository_impl.dart';
import 'features/farm/data/repositories/land_repository_impl.dart';
import 'features/farm/data/repositories/season_repository_impl.dart';
import 'features/farm/domain/repositories/activity_repository.dart';
import 'features/farm/domain/repositories/plant_repository.dart';
import 'features/farm/domain/repositories/farm_repository.dart';
import 'features/farm/domain/repositories/input_repository.dart';
import 'features/farm/domain/repositories/land_repository.dart';
import 'features/farm/domain/repositories/analysis_repository.dart';
import 'features/farm/domain/repositories/season_repository.dart';
import 'features/farm/domain/usecases/add_activity.dart';
import 'features/farm/domain/usecases/add_plant.dart';
import 'features/farm/domain/usecases/add_input.dart';
import 'features/farm/domain/usecases/add_land.dart';
import 'features/farm/domain/usecases/add_season.dart';
import 'features/farm/domain/usecases/get_activities.dart';
import 'features/farm/domain/usecases/get_plants.dart';
import 'features/farm/domain/usecases/get_inputs.dart';
import 'features/farm/domain/usecases/get_lands.dart';
import 'features/farm/domain/usecases/get_seasons.dart';
import 'features/farm/domain/usecases/update_land.dart';
import 'features/farm/domain/usecases/delete_land.dart';
import 'features/farm/domain/usecases/update_plant.dart';
import 'features/farm/domain/usecases/delete_plant.dart';
import 'features/farm/domain/usecases/update_season.dart';
import 'features/farm/domain/usecases/delete_season.dart';
import 'features/farm/domain/usecases/update_activity.dart';
import 'features/farm/domain/usecases/delete_activity.dart';
import 'features/farm/domain/usecases/update_input.dart';
import 'features/farm/domain/usecases/delete_input.dart';
import 'features/farm/domain/usecases/get_total_costs_by_season.dart';
import 'features/farm/domain/usecases/get_cost_breakdown.dart';
import 'features/farm/domain/usecases/get_annual_cost_summary.dart';
import 'features/farm/presentation/bloc/farm_bloc.dart';
import 'features/farm/presentation/bloc/analysis_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Initialize logging
  appLogger.initialize();

  // Bloc
  sl.registerFactory(() => AuthBloc(login: sl(), signup: sl()));
  sl.registerFactory(
    () => FarmBloc(
      getLands: sl(),
      addLand: sl(),
      updateLand: sl(),
      deleteLand: sl(),
      getPlants: sl(),
      addPlant: sl(),
      updatePlant: sl(),
      deletePlant: sl(),
      getSeasons: sl(),
      addSeason: sl(),
      updateSeason: sl(),
      deleteSeason: sl(),
      getActivities: sl(),
      addActivity: sl(),
      updateActivity: sl(),
      deleteActivity: sl(),
      getInputs: sl(),
      addInput: sl(),
      updateInput: sl(),
      deleteInput: sl(),
    ),
  );
  sl.registerFactory(
    () => AnalysisBloc(
      getTotalCostsBySeason: sl(),
      getCostBreakdown: sl(),
      getAnnualCostSummary: sl(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => Login(sl()));
  sl.registerLazySingleton(() => Signup(sl()));
  sl.registerLazySingleton(() => GetLands(sl()));
  sl.registerLazySingleton(() => AddLand(sl()));
  sl.registerLazySingleton(() => UpdateLand(sl()));
  sl.registerLazySingleton(() => DeleteLand(sl()));
  sl.registerLazySingleton(() => GetPlants(sl()));
  sl.registerLazySingleton(() => AddPlant(sl()));
  sl.registerLazySingleton(() => UpdatePlant(sl()));
  sl.registerLazySingleton(() => DeletePlant(sl()));
  sl.registerLazySingleton(() => GetSeasons(sl()));
  sl.registerLazySingleton(() => AddSeason(sl()));
  sl.registerLazySingleton(() => UpdateSeason(sl()));
  sl.registerLazySingleton(() => DeleteSeason(sl()));
  sl.registerLazySingleton(() => GetActivities(sl()));
  sl.registerLazySingleton(() => AddActivity(sl()));
  sl.registerLazySingleton(() => UpdateActivity(sl()));
  sl.registerLazySingleton(() => DeleteActivity(sl()));
  sl.registerLazySingleton(() => GetInputs(sl()));
  sl.registerLazySingleton(() => AddInput(sl()));
  sl.registerLazySingleton(() => UpdateInput(sl()));
  sl.registerLazySingleton(() => DeleteInput(sl()));
  sl.registerLazySingleton(() => GetTotalCostsBySeason(sl()));
  sl.registerLazySingleton(() => GetCostBreakdown(sl()));
  sl.registerLazySingleton(() => GetAnnualCostSummary(sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<FarmRepository>(
    () => FarmRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<LandRepository>(
    () => LandRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<PlantRepository>(
    () => PlantRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<SeasonRepository>(
    () => SeasonRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ActivityRepository>(
    () => ActivityRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<InputRepository>(
    () => InputRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<AnalysisRepository>(
    () => AnalysisRepositoryImpl(remoteDataSource: sl()),
  );

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<FarmRemoteDataSource>(
    () => FarmRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<LandRemoteDataSource>(
    () => LandRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<PlantRemoteDataSource>(
    () => PlantRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<SeasonRemoteDataSource>(
    () => SeasonRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<ActivityRemoteDataSource>(
    () =>
        ActivityRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<InputRemoteDataSource>(
    () => InputRemoteDataSourceImpl(client: sl(), baseUrl: AppConfig.baseUrl),
  );
  sl.registerLazySingleton<AnalysisRemoteDataSource>(
    () => AnalysisRemoteDataSourceImpl(),
  );

  // External
  sl.registerLazySingleton<http.Client>(() => LoggingHttpClient(http.Client()));
  sl.registerLazySingleton(() => FarmDataService());
}
