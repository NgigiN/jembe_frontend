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
    test('logged in -> always allow (null)', () {
      expect(
        WebAppRouter.authRedirectLocation(loggedIn: true, location: WebRoutePath.dashboard),
        isNull,
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
