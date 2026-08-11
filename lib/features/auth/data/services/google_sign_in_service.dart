import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:google_sign_in/google_sign_in.dart' as auth_google;

/// Lazily initializes Google Sign-In only when the user starts authentication.
class GoogleSignInService {
  GoogleSignInService._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    try {
      await auth_google.GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );
      _initialized = true;
    } catch (e) {
      appLogger.error(
        LogCategory.auth,
        'Failed to initialize Google Sign-In',
        e,
      );
      rethrow;
    }
  }
}

