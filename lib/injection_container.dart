import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login.dart';
import 'features/auth/domain/usecases/signup.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/farm/data/datasources/activity_remote_data_source.dart';
import 'features/farm/data/datasources/crop_remote_data_source.dart';
import 'features/farm/data/datasources/farm_remote_data_source.dart';
import 'features/farm/data/datasources/input_remote_data_source.dart';
import 'features/farm/data/datasources/land_remote_data_source.dart';
import 'features/farm/data/datasources/season_remote_data_source.dart';
import 'features/farm/data/datasources/analysis_remote_data_source.dart';
import 'features/farm/data/repositories/activity_repository_impl.dart';
import 'features/farm/data/repositories/analysis_repository_impl.dart';
import 'features/farm/data/repositories/crop_repository_impl.dart';
import 'features/farm/data/services/farm_data_service.dart';
import 'features/farm/data/repositories/farm_repository_impl.dart';
import 'features/farm/data/repositories/input_repository_impl.dart';
import 'features/farm/data/repositories/land_repository_impl.dart';
import 'features/farm/data/repositories/season_repository_impl.dart';
import 'features/farm/domain/repositories/activity_repository.dart';
import 'features/farm/domain/repositories/crop_repository.dart';
import 'features/farm/domain/repositories/farm_repository.dart';
import 'features/farm/domain/repositories/input_repository.dart';
import 'features/farm/domain/repositories/land_repository.dart';
import 'features/farm/domain/repositories/analysis_repository.dart';
import 'features/farm/domain/repositories/season_repository.dart';
import 'features/farm/domain/usecases/add_activity.dart';
import 'features/farm/domain/usecases/add_crop.dart';
import 'features/farm/domain/usecases/add_input.dart';
import 'features/farm/domain/usecases/add_land.dart';
import 'features/farm/domain/usecases/add_season.dart';
import 'features/farm/domain/usecases/get_activities.dart';
import 'features/farm/domain/usecases/get_crops.dart';
import 'features/farm/domain/usecases/get_inputs.dart';
import 'features/farm/domain/usecases/get_lands.dart';
import 'features/farm/domain/usecases/get_seasons.dart';
import 'features/farm/domain/usecases/update_land.dart';
import 'features/farm/domain/usecases/get_total_costs_by_season.dart';
import 'features/farm/domain/usecases/get_cost_breakdown.dart';
import 'features/farm/domain/usecases/get_annual_cost_summary.dart';
import 'features/farm/presentation/bloc/farm_bloc.dart';
import 'features/farm/presentation/bloc/analysis_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Bloc
  sl.registerFactory(() => AuthBloc(login: sl(), signup: sl()));
  sl.registerFactory(
    () => FarmBloc(
      getLands: sl(),
      addLand: sl(),
      updateLand: sl(),
      getCrops: sl(),
      addCrop: sl(),
      getSeasons: sl(),
      addSeason: sl(),
      getActivities: sl(),
      addActivity: sl(),
      getInputs: sl(),
      addInput: sl(),
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
  sl.registerLazySingleton(() => GetCrops(sl()));
  sl.registerLazySingleton(() => AddCrop(sl()));
  sl.registerLazySingleton(() => GetSeasons(sl()));
  sl.registerLazySingleton(() => AddSeason(sl()));
  sl.registerLazySingleton(() => GetActivities(sl()));
  sl.registerLazySingleton(() => AddActivity(sl()));
  sl.registerLazySingleton(() => GetInputs(sl()));
  sl.registerLazySingleton(() => AddInput(sl()));
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
  sl.registerLazySingleton<CropRepository>(
    () => CropRepositoryImpl(remoteDataSource: sl()),
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
    () => AuthRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<FarmRemoteDataSource>(
    () => FarmRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<LandRemoteDataSource>(
    () => LandRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<CropRemoteDataSource>(
    () => CropRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<SeasonRemoteDataSource>(
    () => SeasonRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<ActivityRemoteDataSource>(
    () => ActivityRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<InputRemoteDataSource>(
    () => InputRemoteDataSourceImpl(
      client: sl(),
      baseUrl: 'http://127.0.0.1:8090',
    ),
  ); // Replace with your PocketBase URL
  sl.registerLazySingleton<AnalysisRemoteDataSource>(
    () => AnalysisRemoteDataSourceImpl(),
  );

  // External
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => FarmDataService());
}
