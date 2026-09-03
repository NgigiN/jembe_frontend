import 'package:farm_tracker/core/network/session_expiry_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expire() notifies listeners once', () {
    final n = SessionExpiryNotifier();
    var count = 0;
    n.addListener(() => count++);
    n.expire();
    expect(count, 1);
  });
}
