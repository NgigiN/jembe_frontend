import 'package:farm_tracker/features/auth/data/utils/google_sign_in_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('a cancellation is recognised', () {
    expect(
      isSignInCancellation(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      isTrue,
    );
    expect(
      isSignInCancellation(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.providerConfigurationError,
        ),
      ),
      isFalse,
    );
  });

  // A failed sign-in used to read "Google Sign-In failed. Please try again."
  // and nothing else, with the real reason only in a local log nobody can
  // reach. Naming Google's own code turns an unanswerable support message into
  // one that says what happened.
  test('a failure message names Google\'s own code', () {
    final message = describeSignInFailure(
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.providerConfigurationError,
        description: 'bad client',
      ),
    );
    expect(message, contains('providerConfigurationError'));
  });

  test('a non-Google error still produces a usable message', () {
    final message = describeSignInFailure(StateError('something else'));
    expect(message, isNotEmpty);
    expect(message.toLowerCase(), contains('sign-in'));
  });
}
