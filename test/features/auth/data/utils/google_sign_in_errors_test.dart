import 'package:farm_tracker/features/auth/data/utils/google_sign_in_errors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('canceled exception is a cancellation', () {
    const e = GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
    expect(isSignInCancellation(e), isTrue);
  });

  test('other exceptions are not cancellations', () {
    expect(isSignInCancellation(Exception('network')), isFalse);
    const e = GoogleSignInException(
      code: GoogleSignInExceptionCode.unknownError,
    );
    expect(isSignInCancellation(e), isFalse);
  });
}
