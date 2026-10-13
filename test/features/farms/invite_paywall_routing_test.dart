import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farm_manage_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inviteFailureAction', () {
    test('a 402 opens the paywall', () {
      expect(
        inviteFailureAction(const PaymentRequiredException('no seats')),
        InviteFailure.paywall,
      );
    });

    test('a plain server error is reported in place', () {
      expect(
        inviteFailureAction(const ServerException('already a member')),
        InviteFailure.message,
      );
    });

    test('a network error is reported in place', () {
      expect(inviteFailureAction(NetworkException()), InviteFailure.message);
    });

    test('an unexpected error is still reported rather than swallowed', () {
      expect(inviteFailureAction(StateError('bug')), InviteFailure.message);
    });
  });
}
