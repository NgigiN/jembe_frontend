import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expire() notifies listeners once', () {
    final n = SessionExpiryNotifier();
    var count = 0;
    n
      ..addListener(() => count++)
      ..expire();
    expect(count, 1);
  });

  test('shouldForceLogoutOn401 carves out the public /meta launch check', () {
    expect(shouldForceLogoutOn401('/api/v1/meta'), isFalse);
  });

  test('shouldForceLogoutOn401 still forces logout on protected paths', () {
    expect(shouldForceLogoutOn401('/api/v1/lands'), isTrue);
  });
}
