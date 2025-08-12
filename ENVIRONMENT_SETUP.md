# Environment Configuration Setup

This setup allows you to switch between local and remote backend servers at build/run time using command-line flags.

## Quick Start

1. **Update your remote IP**: Edit `lib/core/config/app_config.dart` and change `_remoteBaseUrl` to your actual remote server IP:
   ```dart
   static const String _remoteBaseUrl = 'http://192.168.1.100:8090'; // Your actual IP
   ```

2. **Run in different environments**:
   - **Local Development**: `./run_local.sh` or `flutter run --dart-define=ENV=local`
   - **Production/Remote**: `./run_production.sh` or `flutter run --dart-define=ENV=production`

3. **Build for production**: `./build_production.sh` or `flutter build apk --dart-define=ENV=production --release`

## How It Works

- **AppConfig.baseUrl** automatically returns the correct URL based on the ENV dart-define flag
- All your existing API calls now use this dynamic base URL
- Environment is set at build/run time, not user-facing
- No UI widgets or user interaction needed

## Files Created/Modified

- `lib/core/config/app_config.dart` - Main configuration class using dart-define
- `run_local.sh` - Script to run in local development mode
- `run_production.sh` - Script to run in production mode
- `build_production.sh` - Script to build production APK/web
- `lib/injection_container.dart` - Updated to use AppConfig.baseUrl
- `lib/features/farm/data/services/farm_data_service.dart` - Updated to use AppConfig.baseUrl

## Usage Examples

### Running the App

```bash
# Local development
./run_local.sh
# or
flutter run --dart-define=ENV=local

# Production/Remote
./run_production.sh
# or
flutter run --dart-define=ENV=production
```

### Building for Production

```bash
# Build Android APK
flutter build apk --dart-define=ENV=production --release

# Build Web
flutter build web --dart-define=ENV=production --release

# Or use the script
./build_production.sh
```

### Getting Base URL in Code

```dart
// This automatically returns the correct URL based on ENV flag
String url = AppConfig.baseUrl;
```

## Benefits

- ✅ No .env files needed
- ✅ Environment set at build/run time
- ✅ No user-facing UI widgets
- ✅ All API calls automatically use correct URL
- ✅ Easy to maintain and extend
- ✅ Production builds always use remote server
- ✅ Development builds can use local server

## Testing

1. **Test local**: Run `./run_local.sh` - should connect to `http://127.0.0.1:8090`
2. **Test production**: Run `./run_production.sh` - should connect to your remote IP
3. **Build production**: Run `./build_production.sh` - creates production builds

## Troubleshooting

- If you get connection errors, check that your remote IP is correct in `AppConfig`
- Make sure your remote server is accessible from your device
- The environment is printed to console when the app starts (in debug mode)
- Production builds will always use the remote server regardless of where they're run
