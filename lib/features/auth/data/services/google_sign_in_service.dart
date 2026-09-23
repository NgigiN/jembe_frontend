import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      // package:google_sign_in_web requires `clientId` (not `serverClientId`,
      // which it explicitly rejects — see google_sign_in_web's gis_client.dart)
      // since this app has no <meta name="google-signin-client_id"> tag in
      // web/index.html. AppConfig.googleServerClientId is already a "Web
      // application"-type OAuth client (see its own doc comment), the correct
      // type for this parameter, so no new Google Cloud Console client is
      // needed — reusing the existing one.
      if (kIsWeb) {
        await auth_google.GoogleSignIn.instance.initialize(
          clientId: AppConfig.googleServerClientId,
        );
      } else {
        await auth_google.GoogleSignIn.instance.initialize(
          serverClientId: AppConfig.googleServerClientId,
        );
      }
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

