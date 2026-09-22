// lib/main_web.dart
//
// Web console entry point (spec §3) — separate from lib/main.dart (mobile).
// Never imports lib/injection_container.dart.
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/pages/feed_page.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_console_shell.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_sign_in_page.dart';
import 'package:farm_tracker/web_injection_container.dart' as web_di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();

  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) {
      AppConfig.appVersion = info.version;
    }
  } catch (_) {
    // Keep the "0.0.0" default; startup must never fail on version lookup —
    // same reasoning as lib/main.dart's identical try/catch.
  }

  await web_di.initWebDependencies();

  runApp(const _WebConsoleApp());
}

class _WebConsoleApp extends StatelessWidget {
  const _WebConsoleApp();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: WebRoutePath.dashboard,
      redirect: (context, state) async {
        final loggedIn = await UserStorageService.isLoggedIn();
        final authRedirect = WebAppRouter.authRedirectLocation(
          loggedIn: loggedIn, location: state.matchedLocation,
        );
        if (authRedirect != null) return authRedirect;
        final role = await FarmStorageService.getCurrentRole();
        return WebAppRouter.staffOnlyRedirectLocation(role: role, location: state.matchedLocation);
      },
      routes: [
        GoRoute(path: WebRoutePath.signIn, builder: (_, __) => const WebSignInPage()),
        ShellRoute(
          builder: (context, state, child) => WebConsoleShell(child: child),
          routes: [
            GoRoute(path: WebRoutePath.dashboard, builder: (_, __) => const Placeholder()),
            GoRoute(path: WebRoutePath.feed, builder: (_, __) => const FeedPage()),
            GoRoute(path: WebRoutePath.members, builder: (_, __) => const Placeholder()),
            GoRoute(path: WebRoutePath.reports, builder: (_, __) => const Placeholder()),
          ],
        ),
      ],
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => web_di.webSl<AuthBloc>()),
        BlocProvider<FarmBloc>(create: (_) => web_di.webSl<FarmBloc>()..add(LoadFarms())),
        BlocProvider<FeedBloc>(create: (_) => web_di.webSl<FeedBloc>()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }
}
