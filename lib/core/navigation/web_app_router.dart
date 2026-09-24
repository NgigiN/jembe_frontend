// lib/core/navigation/web_app_router.dart
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';

class WebRoutePath {
  static const signIn = '/sign-in';
  static const dashboard = '/dashboard';
  static const feed = '/feed';
  static const members = '/members';
  static const reports = '/reports';
  static const farmsList = '/farms';
  static const trash = '/trash';
  static const settings = '/settings';
}

class WebAppRouter {
  static const Set<String> _publicPaths = {WebRoutePath.signIn};

  /// Pure redirect decision (unit-tested).
  ///
  /// Deliberately NOT a mirror of `AppRouter.authRedirectLocation` any
  /// more. Mobile can answer "logged in? then never redirect", because
  /// after a successful sign-in its login page pushes the landing page
  /// itself. The console has no such imperative step — the router's
  /// redirect is the only thing that moves you — so the same answer left a
  /// signed-in user sitting on the sign-in page, looking at the button
  /// they had just pressed, with the token already saved and the backend
  /// having returned 200.
  static String? authRedirectLocation({
    required bool loggedIn,
    required String location,
  }) {
    if (!loggedIn) {
      return _publicPaths.contains(location) ? null : WebRoutePath.signIn;
    }
    // Signed in, still on a public page: the sign-in screen has nothing
    // left to offer. A worker sent to the dashboard bounces on to Feed on
    // the next pass, via staffOnlyRedirectLocation.
    if (_publicPaths.contains(location)) return WebRoutePath.dashboard;
    return null;
  }

  static const Set<String> _staffOnlyPaths = {
    WebRoutePath.dashboard,
    WebRoutePath.reports,
    WebRoutePath.trash,
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
