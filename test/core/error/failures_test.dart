import 'package:farm_tracker/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFailureMessage', () {
    const fallback = 'Something went wrong';

    test('UnauthorizedFailure returns its own message, not the fallback', () {
      // Regression guard (F1-05/S4-C1): a 401 maps to UnauthorizedFailure, and
      // its message must reach the user instead of the caller's generic fallback.
      expect(
        resolveFailureMessage(const UnauthorizedFailure(), fallback),
        'Unauthorized access. Please log in again.',
      );
    });

    test('NetworkFailure returns the network-specific message', () {
      expect(
        resolveFailureMessage(const NetworkFailure(), fallback),
        'No internet connection. Check your network and try again.',
      );
    });

    test('ServerFailure with a message returns that message', () {
      expect(
        resolveFailureMessage(const ServerFailure('boom'), fallback),
        'boom',
      );
    });

    test('ServerFailure without a message falls through to the fallback', () {
      expect(resolveFailureMessage(const ServerFailure(), fallback), fallback);
    });

    test('CacheFailure falls through to the fallback', () {
      expect(resolveFailureMessage(const CacheFailure(), fallback), fallback);
    });
  });
}
