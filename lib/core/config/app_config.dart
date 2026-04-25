import 'package:flutter/foundation.dart';

import 'package:farm_tracker/core/logging/app_logger.dart';

enum Environment { local, remote }

class AppConfig {
  static late Environment _currentEnvironment;

  // Remote server configuration - HTTPS enforced in production
  static const String _remoteBaseUrl = 'https://193.187.129.179:6060';
  // static const String _localBaseUrl = 'http://127.0.0.1:8080';
  static const String _localBaseUrl = 'http://192.168.122.1:8080';

  // Google Sign-In Configuration
  // Note: This must be the "Web Client ID" from Google Cloud Console
  static const String googleServerClientId =
      '429420927444-v5pdh3k3e7a8jhth5fuq1bq6ie49mam4.apps.googleusercontent.com';

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

  // Getter for base URL based on current environment
  static String get baseUrl {
    switch (_currentEnvironment) {
      case Environment.local:
        return _localBaseUrl;
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
