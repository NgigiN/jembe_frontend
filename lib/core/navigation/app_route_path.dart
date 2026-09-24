// lib/core/navigation/app_route_path.dart
//
// Pure route name/path string constants, split out of app_router.dart
// (web-console Task 15.6) so a consumer that only needs these strings
// doesn't have to import app_router.dart's own ~20+ mobile-page imports,
// several of which transitively reach app_database.dart/sqlite3 — fatal
// to a web compile target. Zero behavior change: app_router.dart
// re-exports this file, so every existing `import 'app_router.dart'`
// consumer keeps resolving AppRoutePath/AppRouteName exactly as before.
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
  static const animalsList = 'animals-list';
  static const inputs = 'inputs';
  static const activities = 'activities';
  static const totalCosts = 'total-costs';
  static const costBreakdown = 'cost-breakdown';
  static const annualSummary = 'annual-summary';
  static const streak = 'streak';
  static const revenueAdd = 'revenue-add';
  static const infrastructure = 'infrastructure';
  static const herdActivities = 'herd-activities';
  static const harvests = 'harvests';
  static const contentTips = 'content-tips';
  static const contentDetail = 'content-detail';
  static const askQuestion = 'ask-question';
  static const trash = 'trash';
  static const farmsList = 'farms-list';
  static const createFarm = 'create-farm';
  static const farmManage = 'farm-manage';
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
  static const animalsList = '/animals-list';
  static const inputsTemplate = '/inputs/:sourceType';
  static const activitiesTemplate = '/activities/:sourceType';
  static const totalCosts = '/analytics/total-costs';
  static const costBreakdown = '/analytics/cost-breakdown';
  static const annualSummary = '/analytics/annual-summary';
  static const streak = '/analytics/streak';
  static const revenueAdd = '/revenue/add';
  static const infrastructure = '/infrastructure';
  static const herdActivities = '/herd-activities';
  static const harvests = '/harvests';
  static const contentTips = '/content';
  static const contentDetailTemplate = '/content/:id';
  static const askQuestion = '/ask-question';
  static const trash = '/trash';
  static const farmsList = '/farms';
  static const createFarm = '/farms/create';
  static const farmManage = '/farms/manage';

  static String inputsFor(String sourceType) => '/inputs/$sourceType';
  static String activitiesFor(String sourceType) => '/activities/$sourceType';
  static String contentDetailFor(String id) => '/content/$id';
}
