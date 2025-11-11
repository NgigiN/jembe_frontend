import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/farm/presentation/bloc/farm_bloc.dart';
import 'features/farm/presentation/bloc/farm_event.dart';
import 'features/farm/presentation/bloc/analysis_bloc.dart';
import 'features/farm/presentation/pages/landing_page.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/logging_navigator.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  AppConfig.initialize();

  await di.init();

  // Log app startup
  appLogger.info(LogCategory.general, 'Farm Tracker App Starting');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
        BlocProvider<FarmBloc>(
          create: (_) => di.sl<FarmBloc>()..add(GetLandsEvent()),
        ),
        BlocProvider<AnalysisBloc>(create: (_) => di.sl<AnalysisBloc>()),
      ],
      child: LoggingMaterialApp(
        title: 'Farm Tracking App',
        theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashPage(),
          '/login': (context) => LoginPage(),
          '/landing': (context) => LandingPage(),
        },
      ),
    );
  }
}
