import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/theme/app_theme.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
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
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  AppConfig.initialize();

  await di.init();

  // Log app startup
  appLogger.info(LogCategory.general, 'Shamba+ App Starting');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Flush buffered analytics before the OS may suspend/kill the app -
      // a backgrounded Timer is not reliable, so this is the last
      // guaranteed chance to send whatever is buffered.
      di.sl<AnalyticsService>().flush();
    }
  }

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
        BlocProvider<HarvestBloc>(create: (_) => di.sl<HarvestBloc>()),
        BlocProvider<AnimalTypeBloc>(create: (_) => di.sl<AnimalTypeBloc>()),
        BlocProvider<HerdBloc>(create: (_) => di.sl<HerdBloc>()),
        BlocProvider<HerdActivityBloc>(
          create: (_) => di.sl<HerdActivityBloc>(),
        ),
        BlocProvider<InfrastructureBloc>(
          create: (_) => di.sl<InfrastructureBloc>(),
        ),
        BlocProvider<AnalysisBloc>(create: (_) => di.sl<AnalysisBloc>()),
        BlocProvider<RevenueBloc>(create: (_) => di.sl<RevenueBloc>()),
        BlocProvider<CostCategoryBloc>(
          create: (_) => di.sl<CostCategoryBloc>(),
        ),
        BlocProvider<ProfileBloc>(create: (_) => di.sl<ProfileBloc>()),
        BlocProvider<ContentBloc>(create: (_) => di.sl<ContentBloc>()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Shamba+',
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
