import 'package:dio/dio.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/network/dio_client.dart';
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

Future<void> init() async {
  // Initialize logging
  appLogger.initialize();

  // Bloc
  sl
    ..registerFactory(() => AuthBloc(googleSignInUseCase: sl()))
    // Feature-specific blocs (preferred)
    ..registerFactory(
      () => LandBloc(
        getLands: sl(),
        addLand: sl(),
        updateLand: sl(),
        deleteLand: sl(),
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
    ..registerLazySingleton<LandRepository>(
      () => LandRepositoryImpl(remoteDataSource: sl()),
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
    // External - Dio client (preferred for new code)
    ..registerLazySingleton<Dio>(DioClientFactory.create);
}
