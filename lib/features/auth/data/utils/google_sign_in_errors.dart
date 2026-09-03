import 'package:google_sign_in/google_sign_in.dart';

/// True when [error] is the user backing out of the Google sign-in sheet.
/// google_sign_in v7 throws this instead of returning null.
bool isSignInCancellation(Object error) {
  return error is GoogleSignInException &&
      error.code == GoogleSignInExceptionCode.canceled;
}
