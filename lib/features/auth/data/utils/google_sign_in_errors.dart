import 'package:google_sign_in/google_sign_in.dart';

/// True when [error] is the user backing out of the Google sign-in sheet.
/// google_sign_in v7 throws this instead of returning null.
bool isSignInCancellation(Object error) {
  return error is GoogleSignInException &&
      error.code == GoogleSignInExceptionCode.canceled;
}

/// A message for a sign-in that failed for any reason other than the user
/// backing out.
///
/// Names Google's own failure code, because the previous wording said only
/// "Google Sign-In failed. Please try again." and put the real reason in a
/// local log nobody affected can reach. The code is what distinguishes a
/// misconfigured OAuth client from a network blip, so it belongs in the
/// sentence the reporting user can actually quote back.
String describeSignInFailure(Object error) {
  if (error is GoogleSignInException) {
    return 'Google Sign-In failed (${error.code.name}). Please try again, '
        'and send us that code if it keeps happening.';
  }
  return 'Google Sign-In failed. Please try again.';
}
