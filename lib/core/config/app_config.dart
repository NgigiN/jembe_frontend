import 'package:flutter/foundation.dart';

import 'package:farm_tracker/core/logging/app_logger.dart';

enum Environment { local, remote }

class AppConfig {
  static late Environment _currentEnvironment;

  // Remote server configuration (plain HTTP; backend does not terminate TLS)
  static const String _remoteBaseUrl = 'http://193.187.129.179:6060';
  // Android emulator host loopback; override via --dart-define=LOCAL_API_HOST for devices
  static const String _defaultLocalApiHost = '10.0.2.2';
  static const int _defaultLocalApiPort = 8080;

  // Google Sign-In Configuration
  // Note: This must be the "Web Client ID" from Google Cloud Console
  // static const String googleServerClientId =
  //     '429420927444-v5pdh3k3e7a8jhth5fuq1bq6ie49mam4.apps.googleusercontent.com';
  static const String googleServerClientId =
      '429420927444-bnhb3nvfu3ten0mb77hi8k30q8a67m3h.apps.googleusercontent.com';

  // Initialize environment based on dart-define flags
  static void initialize() {
    // Check for ENV dart-define flag
    const envValue = String.fromEnvironment('ENV', defaultValue: 'local');

    switch (envValue.toLowerCase()) {
      case 'local':
        _currentEnvironment = Environment.local;
      case 'remote':
      case 'production':
        _currentEnvironment = Environment.remote;
      default:
        _currentEnvironment = Environment.local; // Default to local
    }

    if (!kReleaseMode) {
      appLogger.info(
        LogCategory.general,
        'Environment initialized: ${_currentEnvironment.name}',
      );
      appLogger.debug(
        LogCategory.general,
        'Base URL: $baseUrl | ENV dart-define value: "$envValue"',
      );
    }
  }

  // Getter for current environment
  static Environment get currentEnvironment => _currentEnvironment;

  // Override at run time, e.g.:
  // flutter run --dart-define=LOCAL_API_HOST=192.168.100.2
  static String get localApiHost {
    const host = String.fromEnvironment(
      'LOCAL_API_HOST',
      defaultValue: _defaultLocalApiHost,
    );
    return host.trim();
  }

  static int get localApiPort {
    const port = String.fromEnvironment(
      'LOCAL_API_PORT',
      defaultValue: '$_defaultLocalApiPort',
    );
    return int.tryParse(port) ?? _defaultLocalApiPort;
  }

  // Getter for base URL based on current environment
  static String get baseUrl {
    switch (_currentEnvironment) {
      case Environment.local:
        return 'http://${localApiHost}:${localApiPort}';
      case Environment.remote:
        return _remoteBaseUrl;
    }
  }

  // Check if currently using local environment
  static bool get isLocal => _currentEnvironment == Environment.local;

  // Check if currently using remote environment
  static bool get isRemote => _currentEnvironment == Environment.remote;

  // Get environment name for display
  static String get environmentName => _currentEnvironment.name.toUpperCase();
}
