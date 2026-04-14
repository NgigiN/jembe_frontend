import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/farm/presentation/bloc/animal_type_bloc.dart';
import 'features/farm/presentation/bloc/herd_bloc.dart';
import 'features/farm/presentation/bloc/analysis_bloc.dart';
import 'features/farm/presentation/bloc/revenue_bloc.dart';
import 'features/farm/presentation/bloc/land_bloc.dart';
import 'features/farm/presentation/bloc/plant_bloc.dart';
import 'features/farm/presentation/bloc/season_bloc.dart';
import 'features/farm/presentation/bloc/activity_bloc.dart';
import 'features/farm/presentation/bloc/input_bloc.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_state.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/navigation/app_router.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  AppConfig.initialize();

  await di.init();

  // Log app startup
  appLogger.info(LogCategory.general, 'Farm Tracker App Starting');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
        BlocProvider<LandBloc>(create: (_) => di.sl<LandBloc>()),
        BlocProvider<PlantBloc>(create: (_) => di.sl<PlantBloc>()),
        BlocProvider<SeasonBloc>(create: (_) => di.sl<SeasonBloc>()),
        BlocProvider<ActivityBloc>(create: (_) => di.sl<ActivityBloc>()),
        BlocProvider<InputBloc>(create: (_) => di.sl<InputBloc>()),
        BlocProvider<AnimalTypeBloc>(create: (_) => di.sl<AnimalTypeBloc>()),
        BlocProvider<HerdBloc>(create: (_) => di.sl<HerdBloc>()),
        BlocProvider<AnalysisBloc>(create: (_) => di.sl<AnalysisBloc>()),
        BlocProvider<RevenueBloc>(create: (_) => di.sl<RevenueBloc>()),
        BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Farm Tracking App',
            theme: AppTheme.getLightTheme(),
            darkTheme: AppTheme.getDarkTheme(),
            themeMode: themeState.themeMode,
            routerConfig: appRouter.router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
