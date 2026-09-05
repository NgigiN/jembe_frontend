import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analytics and auth 401s do not force logout', () {
    expect(shouldForceLogoutOn401('/api/v1/events'), isFalse);
    expect(shouldForceLogoutOn401('/api/v1/auth/google'), isFalse);
  });
  test('a protected-resource 401 forces logout', () {
    expect(shouldForceLogoutOn401('/api/v1/lands'), isTrue);
    expect(shouldForceLogoutOn401('/api/v1/profile'), isTrue);
  });
}
