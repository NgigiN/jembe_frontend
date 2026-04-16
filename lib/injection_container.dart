import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'core/logging/app_logger.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/signup.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/farm/data/datasources/activity_remote_data_source.dart';
import 'features/farm/data/datasources/plant_remote_data_source.dart';
import 'features/farm/data/datasources/input_remote_data_source.dart';
import 'features/farm/data/datasources/land_remote_data_source.dart';
import 'features/farm/data/datasources/season_remote_data_source.dart';
import 'features/farm/data/datasources/animal_remote_data_source.dart';
import 'features/farm/data/datasources/animal_type_remote_data_source.dart';
import 'features/farm/data/datasources/herd_remote_data_source.dart';
import 'features/farm/data/datasources/analysis_remote_data_source.dart';
import 'features/farm/data/datasources/revenue_remote_data_source.dart';
import 'features/farm/data/repositories/activity_repository_impl.dart';
import 'features/farm/data/repositories/analysis_repository_impl.dart';
import 'features/farm/data/repositories/revenue_repository_impl.dart';
import 'features/farm/data/repositories/plant_repository_impl.dart';
import 'features/farm/data/repositories/input_repository_impl.dart';
import 'features/farm/data/repositories/land_repository_impl.dart';
import 'features/farm/data/repositories/season_repository_impl.dart';
import 'features/farm/data/repositories/animal_repository_impl.dart';
import 'features/farm/data/repositories/animal_type_repository_impl.dart';
import 'features/farm/data/repositories/herd_repository_impl.dart';
import 'features/farm/domain/repositories/activity_repository.dart';
import 'features/farm/domain/repositories/plant_repository.dart';
import 'features/farm/domain/repositories/input_repository.dart';
import 'features/farm/domain/repositories/land_repository.dart';
import 'features/farm/domain/repositories/analysis_repository.dart';
import 'features/farm/domain/repositories/season_repository.dart';
import 'features/farm/domain/repositories/animal_repository.dart';
import 'features/farm/domain/repositories/animal_type_repository.dart';
import 'features/farm/domain/repositories/herd_repository.dart';
import 'features/farm/domain/repositories/revenue_repository.dart';
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
import 'features/farm/domain/usecases/get_animals.dart';
import 'features/farm/domain/usecases/add_animal.dart';
import 'features/farm/domain/usecases/update_animal.dart';
import 'features/farm/domain/usecases/delete_animal.dart';
import 'features/farm/domain/usecases/get_animal_types.dart';
import 'features/farm/domain/usecases/add_animal_type.dart';
import 'features/farm/domain/usecases/update_animal_type.dart';
import 'features/farm/domain/usecases/delete_animal_type.dart';
import 'features/farm/domain/usecases/get_herds.dart';
import 'features/farm/domain/usecases/add_herd.dart';
import 'features/farm/domain/usecases/update_herd.dart';
import 'features/farm/domain/usecases/delete_herd.dart';
import 'features/farm/domain/usecases/get_total_costs_by_season.dart';
import 'features/farm/domain/usecases/get_cost_breakdown.dart';
import 'features/farm/domain/usecases/get_annual_cost_summary.dart';
import 'features/farm/domain/usecases/get_revenues.dart';
import 'features/farm/domain/usecases/get_revenue_by_id.dart';
import 'features/farm/domain/usecases/add_revenue.dart';
import 'features/farm/domain/usecases/update_revenue.dart';
import 'features/farm/domain/usecases/delete_revenue.dart';
import 'features/farm/presentation/bloc/land_bloc.dart';
import 'features/farm/presentation/bloc/plant_bloc.dart';
import 'features/farm/presentation/bloc/season_bloc.dart';
import 'features/farm/presentation/bloc/activity_bloc.dart';
import 'features/farm/presentation/bloc/input_bloc.dart';
import 'features/farm/presentation/bloc/animal_type_bloc.dart';
import 'features/farm/presentation/bloc/herd_bloc.dart';
import 'features/farm/presentation/bloc/analysis_bloc.dart';
import 'features/farm/presentation/bloc/revenue_bloc.dart';
import 'features/profile/data/datasources/profile_remote_data_source.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/domain/usecases/get_profile.dart';
import 'features/profile/domain/usecases/update_profile.dart';
import 'features/profile/domain/usecases/change_password.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Initialize logging
  appLogger.initialize();

  // Bloc
  sl.registerFactory(() => AuthBloc(login: sl(), signup: sl()));

  // Feature-specific blocs (preferred)
  sl.registerFactory(() => LandBloc(
        getLands: sl(),
        addLand: sl(),
        updateLand: sl(),
        deleteLand: sl(),
      ));
  sl.registerFactory(() => PlantBloc(
        getPlants: sl(),
        addPlant: sl(),
        updatePlant: sl(),
        deletePlant: sl(),
      ));
  sl.registerFactory(() => SeasonBloc(
        getSeasons: sl(),
        addSeason: sl(),
        updateSeason: sl(),
        deleteSeason: sl(),
      ));
  sl.registerFactory(() => ActivityBloc(
        getActivities: sl(),
        addActivity: sl(),
        updateActivity: sl(),
        deleteActivity: sl(),
      ));
  sl.registerFactory(() => InputBloc(
        getInputs: sl(),
        addInput: sl(),
        updateInput: sl(),
        deleteInput: sl(),
      ));
  sl.registerFactory(
    () => AnimalTypeBloc(
      getAnimalTypes: sl(),
      addAnimalType: sl(),
      updateAnimalType: sl(),
      deleteAnimalType: sl(),
    ),
  );
  sl.registerFactory(
    () => HerdBloc(
      getHerds: sl(),
      addHerd: sl(),
      updateHerd: sl(),
      deleteHerd: sl(),
    ),
  );
  sl.registerFactory(
    () => AnalysisBloc(
      getTotalCostsBySeason: sl(),
      getCostBreakdown: sl(),
      getAnnualCostSummary: sl(),
    ),
  );
  sl.registerFactory(
    () => RevenueBloc(
      getRevenues: sl(),
      getRevenueById: sl(),
      addRevenue: sl(),
      updateRevenue: sl(),
      deleteRevenue: sl(),
    ),
  );
  sl.registerFactory(
    () => ProfileBloc(
      getProfile: sl(),
      updateProfile: sl(),
      changePassword: sl(),
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
  sl.registerLazySingleton(() => GetAnimals(sl()));
  sl.registerLazySingleton(() => AddAnimal(sl()));
  sl.registerLazySingleton(() => UpdateAnimal(sl()));
  sl.registerLazySingleton(() => DeleteAnimal(sl()));
  sl.registerLazySingleton(() => GetAnimalTypes(sl()));
  sl.registerLazySingleton(() => AddAnimalType(sl()));
  sl.registerLazySingleton(() => UpdateAnimalType(sl()));
  sl.registerLazySingleton(() => DeleteAnimalType(sl()));
  sl.registerLazySingleton(() => GetHerds(sl()));
  sl.registerLazySingleton(() => AddHerd(sl()));
  sl.registerLazySingleton(() => UpdateHerd(sl()));
  sl.registerLazySingleton(() => DeleteHerd(sl()));
  sl.registerLazySingleton(() => GetTotalCostsBySeason(sl()));
  sl.registerLazySingleton(() => GetCostBreakdown(sl()));
  sl.registerLazySingleton(() => GetAnnualCostSummary(sl()));
  sl.registerLazySingleton(() => GetRevenues(sl()));
  sl.registerLazySingleton(() => GetRevenueById(sl()));
  sl.registerLazySingleton(() => AddRevenue(sl()));
  sl.registerLazySingleton(() => UpdateRevenue(sl()));
  sl.registerLazySingleton(() => DeleteRevenue(sl()));
  sl.registerLazySingleton(() => GetProfile(sl()));
  sl.registerLazySingleton(() => UpdateProfile(sl()));
  sl.registerLazySingleton(() => ChangePassword(sl()));

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
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
  sl.registerLazySingleton<AnimalRepository>(
    () => AnimalRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<AnimalTypeRepository>(
    () => AnimalTypeRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<HerdRepository>(
    () => HerdRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<AnalysisRepository>(
    () => AnalysisRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<RevenueRepository>(
    () => RevenueRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl()),
  );

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<LandRemoteDataSource>(
    () => LandRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<PlantRemoteDataSource>(
    () => PlantRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<SeasonRemoteDataSource>(
    () => SeasonRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ActivityRemoteDataSource>(
    () => ActivityRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<InputRemoteDataSource>(
    () => InputRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<AnimalRemoteDataSource>(
    () => AnimalRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<AnimalTypeRemoteDataSource>(
    () => AnimalTypeRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<HerdRemoteDataSource>(
    () => HerdRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<AnalysisRemoteDataSource>(
    () => AnalysisRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<RevenueRemoteDataSource>(
    () => RevenueRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(dio: sl()),
  );

  // External - Dio client (preferred for new code)
  sl.registerLazySingleton<Dio>(
    () => DioClientFactory.create(enableLogging: true, enableCache: true),
  );
}
