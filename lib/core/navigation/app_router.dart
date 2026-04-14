import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/farm/presentation/pages/activity_page.dart';
import '../../features/farm/presentation/pages/analysis_page.dart';
import '../../features/farm/presentation/pages/animal_type_page.dart';
import '../../features/farm/presentation/pages/herd_page.dart';
import '../../features/farm/presentation/pages/input_page.dart';
import '../../features/farm/presentation/pages/land_page.dart';
import '../../features/farm/presentation/pages/landing_page.dart';
import '../../features/farm/presentation/pages/plant_page.dart';
import '../../features/farm/presentation/pages/revenue_page.dart';
import '../../features/farm/presentation/pages/season_page.dart';
import '../logging/logging_navigator.dart';

class AppRouteName {
  static const splash = 'splash';
  static const login = 'login';
  static const signup = 'signup';
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
  static const revenueAll = 'revenue-all';
  static const revenueFilter = 'revenue-filter';
  static const revenueAdd = 'revenue-add';
}

class AppRoutePath {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
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
  static const revenueAll = '/revenue/all';
  static const revenueFilterTemplate = '/revenue/filter/:source';
  static const revenueAdd = '/revenue/add';

  static String inputsFor(String sourceType) => '/inputs/$sourceType';
  static String activitiesFor(String sourceType) => '/activities/$sourceType';
  static String revenueFilterFor(String source) => '/revenue/filter/$source';
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
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        name: AppRouteName.login,
        path: AppRoutePath.login,
        builder: (context, state) => LoginPage(),
      ),
      GoRoute(
        name: AppRouteName.signup,
        path: AppRoutePath.signup,
        builder: (context, state) => SignupPage(),
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
        name: AppRouteName.revenueAll,
        path: AppRoutePath.revenueAll,
        builder: (context, state) => const AllRevenuePage(),
      ),
      GoRoute(
        name: AppRouteName.revenueFilter,
        path: AppRoutePath.revenueFilterTemplate,
        builder: (context, state) {
          final source = state.pathParameters['source'] ?? 'plant';
          return FilteredRevenuePage(source: source);
        },
      ),
      GoRoute(
        name: AppRouteName.revenueAdd,
        path: AppRoutePath.revenueAdd,
        builder: (context, state) => const AddRevenuePage(),
      ),
    ],
  );
}
