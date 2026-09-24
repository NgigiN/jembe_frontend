// test/core/navigation/web_app_router_test.dart
import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebAppRouter.authRedirectLocation', () {
    test('not logged in, non-public path -> sign-in', () {
      expect(
        WebAppRouter.authRedirectLocation(loggedIn: false, location: WebRoutePath.dashboard),
        WebRoutePath.signIn,
      );
    });
    test('not logged in, sign-in path itself -> allow (null)', () {
      expect(
        WebAppRouter.authRedirectLocation(loggedIn: false, location: WebRoutePath.signIn),
        isNull,
      );
    });
    test('logged in, already inside the console -> allow (null)', () {
      for (final path in [
        WebRoutePath.dashboard,
        WebRoutePath.feed,
        WebRoutePath.reports,
        WebRoutePath.members,
        WebRoutePath.farmsList,
        WebRoutePath.trash,
        WebRoutePath.settings,
      ]) {
        expect(
          WebAppRouter.authRedirectLocation(loggedIn: true, location: path),
          isNull,
          reason: path,
        );
      }
    });

    // The console navigates by redirect alone — nothing pushes a route
    // after a successful sign-in — so leaving a signed-in user on the
    // sign-in page is how "I picked my account and nothing happened"
    // happens, with the token already saved and the backend at 200.
    test('logged in, still on the sign-in page -> into the console', () {
      expect(
        WebAppRouter.authRedirectLocation(loggedIn: true, location: WebRoutePath.signIn),
        WebRoutePath.dashboard,
      );
    });

    test('a worker sent to the dashboard is bounced on to Feed', () {
      // Second pass: the redirect above lands on /dashboard, and this is
      // what runs for it.
      expect(
        WebAppRouter.staffOnlyRedirectLocation(
          role: FarmRole.worker,
          location: WebRoutePath.dashboard,
        ),
        WebRoutePath.feed,
      );
    });
  });

  group('WebAppRouter.staffOnlyRedirectLocation', () {
    test('null role (not loaded yet) never redirects', () {
      expect(
        WebAppRouter.staffOnlyRedirectLocation(role: null, location: WebRoutePath.dashboard),
        isNull,
      );
    });
    test('worker hitting dashboard -> redirected to feed', () {
      expect(
        WebAppRouter.staffOnlyRedirectLocation(role: FarmRole.worker, location: WebRoutePath.dashboard),
        WebRoutePath.feed,
      );
    });
    test('worker hitting reports -> redirected to feed', () {
      expect(
        WebAppRouter.staffOnlyRedirectLocation(role: FarmRole.worker, location: WebRoutePath.reports),
        WebRoutePath.feed,
      );
    });
    test('worker hitting feed -> allowed (null)', () {
      expect(
        WebAppRouter.staffOnlyRedirectLocation(role: FarmRole.worker, location: WebRoutePath.feed),
        isNull,
      );
    });
    test('worker hitting members -> allowed (null)', () {
      expect(
        WebAppRouter.staffOnlyRedirectLocation(role: FarmRole.worker, location: WebRoutePath.members),
        isNull,
      );
    });
    test('manager hitting dashboard -> allowed (null)', () {
      expect(
        WebAppRouter.staffOnlyRedirectLocation(role: FarmRole.manager, location: WebRoutePath.dashboard),
        isNull,
      );
    });
  });
}
