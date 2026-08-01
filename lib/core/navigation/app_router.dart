import 'package:animations/animations.dart';
import 'package:farm_tracker/core/logging/logging_navigator.dart';
import 'package:farm_tracker/features/auth/presentation/pages/google_login_page.dart';
import 'package:farm_tracker/features/auth/presentation/pages/onboarding_page.dart';
import 'package:farm_tracker/features/auth/presentation/pages/splash_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/activity_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';
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
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouteName {
  static const splash = 'splash';
  static const googleLogin = 'google-login';
  static const onboarding = 'onboarding';
  static const plantsDashboard = 'plants-dashboard';
  static const analytics = 'analytics';
  static const animalsDashboard = 'animals-dashboard';
  static const revenue = 'revenue';
  static const settings = 'settings';
  static const lands = 'lands';
  static const plants = 'plants';
  static const seasons = 'seasons';
  static const animalTypes = 'animal-types';
  static const herds = 'herds';
  static const inputs = 'inputs';
  static const activities = 'activities';
  static const totalCosts = 'total-costs';
  static const costBreakdown = 'cost-breakdown';
  static const annualSummary = 'annual-summary';
  static const revenueAdd = 'revenue-add';
  static const infrastructure = 'infrastructure';
  static const herdActivities = 'herd-activities';
  static const harvests = 'harvests';
}

class AppRoutePath {
  static const splash = '/splash';
  static const googleLogin = '/google-login';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const analytics = '/analytics';
  static const animals = '/animals';
  static const revenue = '/revenue';
  static const settingsPage = '/settings';
  static const lands = '/lands';
  static const plants = '/plants';
  static const seasons = '/seasons';
  static const animalTypes = '/animal-types';
  static const herds = '/herds';
  static const inputsTemplate = '/inputs/:sourceType';
  static const activitiesTemplate = '/activities/:sourceType';
  static const totalCosts = '/analytics/total-costs';
  static const costBreakdown = '/analytics/cost-breakdown';
  static const annualSummary = '/analytics/annual-summary';
  static const revenueAdd = '/revenue/add';
  static const infrastructure = '/infrastructure';
  static const herdActivities = '/herd-activities';
  static const harvests = '/harvests';

  static String inputsFor(String sourceType) => '/inputs/$sourceType';
  static String activitiesFor(String sourceType) => '/activities/$sourceType';
}

class AppRouter {
  AppRouter();

  final GoRouter router = GoRouter(
    initialLocation: AppRoutePath.splash,
    observers: [LoggingGoRouterObserver()],
    routes: [
      GoRoute(
        name: AppRouteName.splash,
        path: AppRoutePath.splash,
        pageBuilder: (context, state) => _fadePage(const SplashPage(), state),
      ),
      GoRoute(
        name: AppRouteName.googleLogin,
        path: AppRoutePath.googleLogin,
        pageBuilder: (context, state) =>
            _fadePage(const GoogleLoginPage(), state),
      ),
      GoRoute(
        name: AppRouteName.onboarding,
        path: AppRoutePath.onboarding,
        pageBuilder: (context, state) =>
            _fadePage(const OnboardingPage(), state),
      ),
      ShellRoute(
        builder: (context, state, child) => LandingPage(child: child),
        routes: [
          GoRoute(
            name: AppRouteName.plantsDashboard,
            path: '/',
            builder: (context, state) => const PlantsPage(),
          ),
          GoRoute(
            name: AppRouteName.animalsDashboard,
            path: '/animals',
            builder: (context, state) => const AnimalsPage(),
          ),
          GoRoute(
            name: AppRouteName.revenue,
            path: '/revenue',
            builder: (context, state) => const RevenuePage(),
          ),
          GoRoute(
            name: AppRouteName.analytics,
            path: '/analytics',
            builder: (context, state) => const AnalysisPage(),
          ),
          GoRoute(
            name: AppRouteName.settings,
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteName.lands,
        path: AppRoutePath.lands,
        pageBuilder: (context, state) => _slidePage(const LandPage(), state),
      ),
      GoRoute(
        name: AppRouteName.plants,
        path: AppRoutePath.plants,
        pageBuilder: (context, state) => _slidePage(const PlantPage(), state),
      ),
      GoRoute(
        name: AppRouteName.seasons,
        path: AppRoutePath.seasons,
        pageBuilder: (context, state) => _slidePage(const SeasonPage(), state),
      ),
      GoRoute(
        name: AppRouteName.animalTypes,
        path: AppRoutePath.animalTypes,
        pageBuilder: (context, state) =>
            _slidePage(const AnimalTypePage(), state),
      ),
      GoRoute(
        name: AppRouteName.herds,
        path: AppRoutePath.herds,
        pageBuilder: (context, state) => _slidePage(const HerdPage(), state),
      ),
      GoRoute(
        name: AppRouteName.inputs,
        path: AppRoutePath.inputsTemplate,
        pageBuilder: (context, state) {
          final sourceType = state.pathParameters['sourceType'] ?? 'plant';
          return _slidePage(InputPage(sourceType: sourceType), state);
        },
      ),
      GoRoute(
        name: AppRouteName.activities,
        path: AppRoutePath.activitiesTemplate,
        pageBuilder: (context, state) {
          final sourceType = state.pathParameters['sourceType'] ?? 'plant';
          return _slidePage(ActivityPage(sourceType: sourceType), state);
        },
      ),
      GoRoute(
        name: AppRouteName.totalCosts,
        path: AppRoutePath.totalCosts,
        pageBuilder: (context, state) =>
            _slidePage(const TotalCostsBySeasonPage(), state),
      ),
      GoRoute(
        name: AppRouteName.costBreakdown,
        path: AppRoutePath.costBreakdown,
        pageBuilder: (context, state) =>
            _slidePage(const CostBreakdownPage(), state),
      ),
      GoRoute(
        name: AppRouteName.annualSummary,
        path: AppRoutePath.annualSummary,
        pageBuilder: (context, state) =>
            _slidePage(const AnnualSummaryPage(), state),
      ),
      GoRoute(
        name: AppRouteName.revenueAdd,
        path: AppRoutePath.revenueAdd,
        pageBuilder: (context, state) =>
            _slidePage(const AddRevenuePage(), state),
      ),
      GoRoute(
        name: AppRouteName.infrastructure,
        path: AppRoutePath.infrastructure,
        pageBuilder: (context, state) =>
            _slidePage(const InfrastructurePage(), state),
      ),
      GoRoute(
        name: AppRouteName.herdActivities,
        path: AppRoutePath.herdActivities,
        pageBuilder: (context, state) =>
            _slidePage(const HerdActivityPage(), state),
      ),
      GoRoute(
        name: AppRouteName.harvests,
        path: AppRoutePath.harvests,
        pageBuilder: (context, state) => _slidePage(const HarvestPage(), state),
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

