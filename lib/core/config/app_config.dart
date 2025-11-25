enum Environment { local, remote }

class AppConfig {
  static late Environment _currentEnvironment;

  // Remote server configuration
  static const String _remoteBaseUrl = 'http://193.187.129.179:6060';
  // static const String _localBaseUrl = 'http://127.0.0.1:8080';
  static const String _localBaseUrl = 'http://192.168.100.5:8080';

  // Initialize environment based on dart-define flags
  static void initialize() {
    // Check for ENV dart-define flag
    const envValue = String.fromEnvironment('ENV', defaultValue: 'local');

    switch (envValue.toLowerCase()) {
      case 'local':
        _currentEnvironment = Environment.local;
        break;
      case 'remote':
      case 'production':
        _currentEnvironment = Environment.remote;
        break;
      default:
        _currentEnvironment = Environment.local; // Default to local
    }

    // Always print in production builds for debugging
    print('Environment initialized: ${_currentEnvironment.name}');
    print('Base URL: $baseUrl');
    print('ENV dart-define value: "$envValue"');
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
