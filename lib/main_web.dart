// lib/main_web.dart
//
// Web console entry point (spec §3) — separate from lib/main.dart (mobile).
// Never imports lib/injection_container.dart.
//
// The three reused sub-project 3 pages below (FarmsListPage, CreateFarmPage,
// FarmManagePage) were previously blocked from being wired in here: they
// transitively reached lib/injection_container.dart's dart:ffi-based
// package:sqlite3 bindings via two import chains (farms_list_page.dart ->
// app_router.dart's AppRoutePath -> ~20+ mobile pages; and
// farm_manage_page.dart/create_farm_page.dart -> injection_container.dart
// directly for `sl<FarmRemoteDataSource>()`), which fail to compile for
// web. Task 15.6 (commit 8dabbe4) decoupled both chains: the pages now
// import lib/core/navigation/app_route_path.dart (plain path-string
// constants, no page imports) and lib/core/di/service_locator.dart (a
// standalone `sl = GetIt.instance` accessor, no sqlite3-touching
// registrations), so importing them here no longer drags in mobile's
// database/sync stack. `flutter build web -t lib/main_web.dart` succeeds
// with this wiring in place (see task-16-report.md).
import 'dart:async';

import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:farm_tracker/core/theme/bloc/theme_bloc.dart';
import 'package:farm_tracker/core/theme/bloc/theme_state.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/pages/create_farm_page.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farm_manage_page.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farms_list_page.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/pages/feed_page.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_console_shell.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_dashboard_page.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_reports_page.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_sign_in_page.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
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

  // A hard 401 on a protected resource (see session_expiry_notifier.dart)
  // forces logout regardless of which page is active — same reasoning as
  // lib/main.dart's identical wiring. AuthBloc is a webSl singleton, so this
  // reaches the exact instance the widget tree below uses; logout when
  // already logged out is a harmless no-op.
  web_di.webSl<SessionExpiryNotifier>().addListener(() {
    web_di.webSl<AuthBloc>().add(LogoutEvent());
  });

  runApp(const _WebConsoleApp());
}

/// Bridges a Stream into a Listenable so GoRouter's `refreshListenable` can
/// react to it — the standard go_router pattern for bloc-driven redirects.
/// Notifies once immediately (matching the pattern's usual form) and again
/// on every stream event.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

class _WebConsoleApp extends StatefulWidget {
  const _WebConsoleApp();

  @override
  State<_WebConsoleApp> createState() => _WebConsoleAppState();
}

class _WebConsoleAppState extends State<_WebConsoleApp> {
  late final GoRouter _router;
  late final _GoRouterRefreshStream _refreshListenable;

  @override
  void initState() {
    super.initState();
    _refreshListenable = _GoRouterRefreshStream(web_di.webSl<AuthBloc>().stream);
    _router = GoRouter(
      initialLocation: WebRoutePath.dashboard,
      refreshListenable: _refreshListenable,
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
        GoRoute(path: WebRoutePath.farmsList, builder: (_, __) => const FarmsListPage()),
        GoRoute(
          path: WebRoutePath.createFarm,
          builder: (_, __) => CreateFarmPage(remote: web_di.webSl<FarmRemoteDataSource>()),
        ),
        GoRoute(
          path: WebRoutePath.farmManage,
          builder: (_, __) => FarmManagePage(remote: web_di.webSl<FarmRemoteDataSource>()),
        ),
        ShellRoute(
          builder: (context, state, child) => WebConsoleShell(child: child),
          routes: [
            GoRoute(path: WebRoutePath.dashboard, builder: (_, __) => const WebDashboardPage()),
            GoRoute(path: WebRoutePath.feed, builder: (_, __) => const FeedPage()),
            GoRoute(
              path: WebRoutePath.members,
              builder: (_, __) => FarmManagePage(remote: web_di.webSl<FarmRemoteDataSource>()),
            ),
            GoRoute(path: WebRoutePath.reports, builder: (_, __) => const WebReportsPage()),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _refreshListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => web_di.webSl<AuthBloc>()),
        BlocProvider<DashboardBloc>(create: (_) => web_di.webSl<DashboardBloc>()),
        BlocProvider<AnalysisBloc>(create: (_) => web_di.webSl<AnalysisBloc>()),
        BlocProvider<FarmBloc>(create: (_) => web_di.webSl<FarmBloc>()..add(LoadFarms())),
        BlocProvider<FeedBloc>(create: (_) => web_di.webSl<FeedBloc>()),
        BlocProvider<ThemeBloc>(create: (_) => web_di.webSl<ThemeBloc>()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp.router(
            title: 'Shamba+',
            theme: WebConsoleTheme.light(),
            darkTheme: WebConsoleTheme.dark(),
            themeMode: themeState.themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
