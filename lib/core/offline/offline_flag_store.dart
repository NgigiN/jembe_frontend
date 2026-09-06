import 'package:shared_preferences/shared_preferences.dart';

/// Persists the server-controlled `offline_enabled` kill-switch locally.
///
/// The server's `/meta` response carries an `offline_enabled` boolean (see
/// `parseOfflineEnabled` in `core/version/version_check.dart`); this store is
/// how that value survives across launches. It matters because `/meta` is
/// only reachable when the device is online — reading it fresh on every
/// launch and falling back to `false` on failure would disable offline mode
/// exactly when the device is offline at launch, which is backwards. So the
/// last-known value is persisted here and read synchronously-early in
/// `main()` (a local read, no network) before anything else resolves.
///
/// Uses plain `shared_preferences` (not `FlutterSecureStorage`, unlike
/// `UserStorageService`) because this flag is not a secret.
class OfflineFlagStore {
  const OfflineFlagStore();

  static const String _key = 'offline_enabled';

  /// The last-persisted value, defaulting to `false` when never written
  /// (matches `OfflineConfig.enabled`'s compile-time default).
  Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Persists [value] so the next launch's [read] picks it up.
  Future<void> write({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
