import 'package:animations/animations.dart';
import 'package:farm_tracker/core/logging/logging_navigator.dart';
import 'package:farm_tracker/core/navigation/app_route_path.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/presentation/pages/google_login_page.dart';
import 'package:farm_tracker/features/auth/presentation/pages/onboarding_page.dart';
import 'package:farm_tracker/features/auth/presentation/pages/splash_page.dart';
import 'package:farm_tracker/features/content/presentation/pages/ask_question_page.dart';
import 'package:farm_tracker/features/content/presentation/pages/content_detail_page.dart';
import 'package:farm_tracker/features/content/presentation/pages/content_list_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/activity_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/annual_summary_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/cost_breakdown_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/streak_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/total_costs_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animals_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/harvest_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_activity_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/infrastructure_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/input_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/landing_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plant_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plants_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/revenue_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/season_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/settings_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/trash_page.dart';
import 'package:farm_tracker/features/farms/data/services/farm_storage_service.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/pages/create_farm_page.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farm_manage_page.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farms_list_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

export 'package:farm_tracker/core/navigation/app_route_path.dart';

class AppRouter {
  AppRouter();

  /// Routes reachable without a session.
  static const Set<String> _publicPaths = {
    AppRoutePath.splash,
    AppRoutePath.googleLogin,
    AppRoutePath.onboarding,
  };

  /// Pure redirect decision (unit-tested): where to send a navigation, or
  /// null to allow it. Defense-in-depth — the API rejects unauthenticated
  /// calls regardless; this turns "errors on every screen" into the login
  /// page (audit S4-C3).
  static String? authRedirectLocation({
    required bool loggedIn,
    required String location,
  }) {
    if (loggedIn) return null;
    if (_publicPaths.contains(location)) return null;
    return AppRoutePath.googleLogin;
  }

  /// Revenue/Analytics/Trash and their sub-routes — matches the real
  /// `staff` (owner+manager) gate on `/revenue`, `/analytics`, `/trash` in
  /// `internal/routes/routes.go`. A worker hitting these entirely
  /// legitimately gets a flat 403 from the backend; this turns that into a
  /// redirect before the request is ever made.
  static const Set<String> _staffOnlyPaths = {
    AppRoutePath.revenue,
    AppRoutePath.revenueAdd,
    AppRoutePath.analytics,
    AppRoutePath.totalCosts,
    AppRoutePath.costBreakdown,
    AppRoutePath.annualSummary,
    AppRoutePath.streak,
    AppRoutePath.trash,
  };

  /// No dedicated owner-only ROUTE exists in this sub-project — the
  /// successor/transfer controls live as a section inside `FarmManagePage`,
  /// a page every role can open. Declared empty (rather than omitted) so a
  /// future owner-only route has an obvious place to register itself.
  static const Set<String> _ownerOnlyPaths = {};

  /// Pure redirect decision (unit-tested): where to send a navigation given
  /// the current farm [role], or null to allow it. Defense-in-depth exactly
  /// like [authRedirectLocation] — the backend rejects the call regardless;
  /// this turns "a 403 on every screen" into a redirect home. A `null`
  /// [role] (farm data not loaded yet) never redirects — `FarmBloc` has its
  /// own load lifecycle; this only gates once a role is actually known.
  static String? staffOnlyRedirectLocation({
    required FarmRole? role,
    required String location,
  }) {
    if (role == null) return null;
    if (_staffOnlyPaths.contains(location) && !role.isStaff) {
      return AppRoutePath.home;
    }
    if (_ownerOnlyPaths.contains(location) && role != FarmRole.owner) {
      return AppRoutePath.home;
    }
    return null;
  }

  final GoRouter router = GoRouter(
    initialLocation: AppRoutePath.splash,
    observers: [LoggingGoRouterObserver()],
    redirect: (context, state) async {
      final loggedIn = await UserStorageService.isLoggedIn();
      final authRedirect = authRedirectLocation(
        loggedIn: loggedIn,
        location: state.matchedLocation,
      );
      if (authRedirect != null) return authRedirect;

      final role = await FarmStorageService.getCurrentRole();
      return staffOnlyRedirectLocation(role: role, location: state.matchedLocation);
    },
    routes: [
      GoRoute(
        name: AppRouteName.splash,
        path: AppRoutePath.splash,
        caseSensitive: false,
        pageBuilder: (context, state) => _fadePage(const SplashPage(), state),
      ),
      GoRoute(
        name: AppRouteName.googleLogin,
        path: AppRoutePath.googleLogin,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _fadePage(const GoogleLoginPage(), state),
      ),
      GoRoute(
        name: AppRouteName.onboarding,
        path: AppRoutePath.onboarding,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _fadePage(const OnboardingPage(), state),
      ),
      ShellRoute(
        // go_router 17 defaults ShellRoute-internal navigation changes to
        // notifying the root GoRouter observers. Pinned to false to keep
        // LoggingGoRouterObserver's pre-17 signal (root pushes/pops only).
        notifyRootObserver: false,
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(
            name: AppRouteName.plantsDashboard,
            path: '/',
            caseSensitive: false,
            pageBuilder: (context, state) =>
                _fadeThroughPage(const PlantsPage(), state),
          ),
          GoRoute(
            name: AppRouteName.animalsDashboard,
            path: '/animals',
            caseSensitive: false,
            pageBuilder: (context, state) =>
                _fadeThroughPage(const AnimalsPage(), state),
          ),
          GoRoute(
            name: AppRouteName.revenue,
            path: '/revenue',
            caseSensitive: false,
            pageBuilder: (context, state) =>
                _fadeThroughPage(const RevenuePage(), state),
          ),
          GoRoute(
            name: AppRouteName.analytics,
            path: '/analytics',
            caseSensitive: false,
            pageBuilder: (context, state) =>
                _fadeThroughPage(const AnalysisPage(), state),
          ),
          GoRoute(
            name: AppRouteName.settings,
            path: '/settings',
            caseSensitive: false,
            pageBuilder: (context, state) =>
                _fadeThroughPage(const SettingsPage(), state),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteName.farmsList,
        path: AppRoutePath.farmsList,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const FarmsListPage(), state),
      ),
      GoRoute(
        name: AppRouteName.createFarm,
        path: AppRoutePath.createFarm,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const CreateFarmPage(), state),
      ),
      GoRoute(
        name: AppRouteName.farmManage,
        path: AppRoutePath.farmManage,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const FarmManagePage(), state),
      ),
      GoRoute(
        name: AppRouteName.lands,
        path: AppRoutePath.lands,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const LandPage(), state),
      ),
      GoRoute(
        name: AppRouteName.plants,
        path: AppRoutePath.plants,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const PlantPage(), state),
      ),
      GoRoute(
        name: AppRouteName.seasons,
        path: AppRoutePath.seasons,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const SeasonPage(), state),
      ),
      GoRoute(
        name: AppRouteName.animalTypes,
        path: AppRoutePath.animalTypes,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const AnimalTypePage(), state),
      ),
      GoRoute(
        name: AppRouteName.herds,
        path: AppRoutePath.herds,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const HerdPage(), state),
      ),
      GoRoute(
        name: AppRouteName.animalsList,
        path: AppRoutePath.animalsList,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const AnimalPage(), state),
      ),
      GoRoute(
        name: AppRouteName.inputs,
        path: AppRoutePath.inputsTemplate,
        caseSensitive: false,
        pageBuilder: (context, state) {
          final sourceType = state.pathParameters['sourceType'] ?? 'plant';
          return _slidePage(InputPage(sourceType: sourceType), state);
        },
      ),
      GoRoute(
        name: AppRouteName.activities,
        path: AppRoutePath.activitiesTemplate,
        caseSensitive: false,
        pageBuilder: (context, state) {
          final sourceType = state.pathParameters['sourceType'] ?? 'plant';
          return _slidePage(ActivityPage(sourceType: sourceType), state);
        },
      ),
      GoRoute(
        name: AppRouteName.totalCosts,
        path: AppRoutePath.totalCosts,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const TotalCostsBySeasonPage(), state),
      ),
      GoRoute(
        name: AppRouteName.costBreakdown,
        path: AppRoutePath.costBreakdown,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const CostBreakdownPage(), state),
      ),
      GoRoute(
        name: AppRouteName.annualSummary,
        path: AppRoutePath.annualSummary,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const AnnualSummaryPage(), state),
      ),
      GoRoute(
        name: AppRouteName.streak,
        path: AppRoutePath.streak,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const StreakPage(), state),
      ),
      GoRoute(
        name: AppRouteName.revenueAdd,
        path: AppRoutePath.revenueAdd,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const AddRevenuePage(), state),
      ),
      GoRoute(
        name: AppRouteName.infrastructure,
        path: AppRoutePath.infrastructure,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const InfrastructurePage(), state),
      ),
      GoRoute(
        name: AppRouteName.herdActivities,
        path: AppRoutePath.herdActivities,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const HerdActivityPage(), state),
      ),
      GoRoute(
        name: AppRouteName.harvests,
        path: AppRoutePath.harvests,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const HarvestPage(), state),
      ),
      GoRoute(
        name: AppRouteName.contentTips,
        path: AppRoutePath.contentTips,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const ContentListPage(), state),
      ),
      GoRoute(
        name: AppRouteName.contentDetail,
        path: AppRoutePath.contentDetailTemplate,
        caseSensitive: false,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return _slidePage(ContentDetailPage(contentId: id), state);
        },
      ),
      GoRoute(
        name: AppRouteName.askQuestion,
        path: AppRoutePath.askQuestion,
        caseSensitive: false,
        pageBuilder: (context, state) =>
            _slidePage(const AskQuestionPage(), state),
      ),
      GoRoute(
        name: AppRouteName.trash,
        path: AppRoutePath.trash,
        caseSensitive: false,
        pageBuilder: (context, state) => _slidePage(const TrashPage(), state),
      ),
    ],
  );

  static CustomTransitionPage<void> _slidePage(
    Widget child,
    GoRouterState state,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          sharedAxisTransition(
            context: context,
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
    );
  }

  /// Drives both the outgoing and incoming page from the same animation,
  /// unlike a plain SlideTransition which only moves the incoming page and
  /// leaves the outgoing one frozen. Falls back to an instant cut when the
  /// user has reduced motion enabled.
  static Widget sharedAxisTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }

  static CustomTransitionPage<void> _fadeThroughPage(
    Widget child,
    GoRouterState state,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          fadeThroughTransitionBuilder(
            context: context,
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          ),
    );
  }

  /// Used for the bottom-nav tabs, which aren't hierarchically related to
  /// each other - a directional slide would be the wrong signal. Falls back
  /// to an instant cut when the user has reduced motion enabled.
  static Widget fadeThroughTransitionBuilder({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return FadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      fillColor: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }

  static CustomTransitionPage<void> _fadePage(
    Widget child,
    GoRouterState state,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
