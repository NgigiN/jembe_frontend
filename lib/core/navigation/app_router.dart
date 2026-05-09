import 'package:go_router/go_router.dart';

import 'package:farm_tracker/features/auth/presentation/pages/google_login_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/activity_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/input_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/landing_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/plant_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/revenue_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/season_page.dart';
import 'package:farm_tracker/core/logging/logging_navigator.dart';

class AppRouteName {
  static const splash = 'splash';
  static const googleLogin = 'google-login';
  static const onboarding = 'onboarding';
  static const landing = 'landing';
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
}

class AppRoutePath {
  static const splash = '/';
  static const googleLogin = '/google-login';
  static const onboarding = '/onboarding';
  static const landing = '/landing';
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

  static String inputsFor(String sourceType) => '/inputs/$sourceType';
  static String activitiesFor(String sourceType) => '/activities/$sourceType';
}

class AppRouter {
  AppRouter();

  final GoRouter router = GoRouter(
    initialLocation: AppRoutePath.googleLogin,
    observers: [LoggingGoRouterObserver()],
    routes: [
      GoRoute(
        name: AppRouteName.googleLogin,
        path: AppRoutePath.googleLogin,
        builder: (context, state) => const GoogleLoginPage(),
      ),
      GoRoute(
        name: AppRouteName.landing,
        path: AppRoutePath.landing,
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        name: AppRouteName.lands,
        path: AppRoutePath.lands,
        builder: (context, state) => const LandPage(),
      ),
      GoRoute(
        name: AppRouteName.plants,
        path: AppRoutePath.plants,
        builder: (context, state) => const PlantPage(),
      ),
      GoRoute(
        name: AppRouteName.seasons,
        path: AppRoutePath.seasons,
        builder: (context, state) => const SeasonPage(),
      ),
      GoRoute(
        name: AppRouteName.animalTypes,
        path: AppRoutePath.animalTypes,
        builder: (context, state) => const AnimalTypePage(),
      ),
      GoRoute(
        name: AppRouteName.herds,
        path: AppRoutePath.herds,
        builder: (context, state) => const HerdPage(),
      ),
      GoRoute(
        name: AppRouteName.inputs,
        path: AppRoutePath.inputsTemplate,
        builder: (context, state) {
          final sourceType = state.pathParameters['sourceType'] ?? 'plant';
          return InputPage(sourceType: sourceType);
        },
      ),
      GoRoute(
        name: AppRouteName.activities,
        path: AppRoutePath.activitiesTemplate,
        builder: (context, state) {
          final sourceType = state.pathParameters['sourceType'] ?? 'plant';
          return ActivityPage(sourceType: sourceType);
        },
      ),
      GoRoute(
        name: AppRouteName.totalCosts,
        path: AppRoutePath.totalCosts,
        builder: (context, state) => const TotalCostsBySeasonPage(),
      ),
      GoRoute(
        name: AppRouteName.costBreakdown,
        path: AppRoutePath.costBreakdown,
        builder: (context, state) => const CostBreakdownPage(),
      ),
      GoRoute(
        name: AppRouteName.annualSummary,
        path: AppRoutePath.annualSummary,
        builder: (context, state) => const AnnualSummaryPage(),
      ),
      GoRoute(
        name: AppRouteName.revenueAdd,
        path: AppRoutePath.revenueAdd,
        builder: (context, state) => const AddRevenuePage(),
      ),
    ],
  );
}
