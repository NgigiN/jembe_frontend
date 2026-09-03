import 'package:dynamic_color/dynamic_color.dart';
import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/theme/app_theme.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/question_bloc.dart';
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
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  AppConfig.initialize();

  await di.init();

  // A hard 401 on a protected resource (see session_expiry_notifier.dart)
  // forces logout regardless of which screen is active. AuthBloc is a DI
  // singleton (see injection_container.dart), so this reaches the exact
  // instance BlocProvider hands to the widget tree below - logout when
  // already logged out is a harmless no-op (UserStorageService.clearUserData
  // and GoogleSignIn.signOut are both idempotent).
  di.sl<SessionExpiryNotifier>().addListener(() {
    di.sl<AuthBloc>().add(LogoutEvent());
  });

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
  final AppRouter _appRouter = AppRouter();

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
        BlocProvider<AnimalBloc>(create: (_) => di.sl<AnimalBloc>()),
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
        BlocProvider<QuestionBloc>(create: (_) => di.sl<QuestionBloc>()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
      ],
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp.router(
                title: 'Shamba+',
                theme: AppTheme.getLightTheme(
                  lightDynamic ?? AppColors.lightColorScheme,
                ),
                darkTheme: AppTheme.getDarkTheme(
                  darkDynamic ?? AppColors.darkColorScheme,
                ),
                themeMode: themeState.themeMode,
                routerConfig: _appRouter.router,
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}
