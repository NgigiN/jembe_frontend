// lib/core/navigation/web_app_router.dart
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class WebRoutePath {
  static const signIn = '/sign-in';
  static const dashboard = '/dashboard';
  static const feed = '/feed';
  static const members = '/members';
  static const reports = '/reports';
  static const farmsList = '/farms';
  static const createFarm = '/farms/create';
  static const farmManage = '/farms/manage';
}

class WebAppRouter {
  static const Set<String> _publicPaths = {WebRoutePath.signIn};

  /// Pure redirect decision (unit-tested), mirrors AppRouter.authRedirectLocation.
  static String? authRedirectLocation({
    required bool loggedIn,
    required String location,
  }) {
    if (loggedIn) return null;
    if (_publicPaths.contains(location)) return null;
    return WebRoutePath.signIn;
  }

  static const Set<String> _staffOnlyPaths = {
    WebRoutePath.dashboard,
    WebRoutePath.reports,
  };

  /// Pure redirect decision (unit-tested), mirrors AppRouter.staffOnlyRedirectLocation.
  /// A worker landing on a staff-only path is sent to Feed — the first
  /// destination actually available to them (spec §5).
  static String? staffOnlyRedirectLocation({
    required FarmRole? role,
    required String location,
  }) {
    if (role == null) return null;
    if (_staffOnlyPaths.contains(location) && !role.isStaff) {
      return WebRoutePath.feed;
    }
    return null;
  }
}
