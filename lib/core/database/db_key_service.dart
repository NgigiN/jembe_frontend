import 'dart:math';

import 'package:farm_tracker/core/analytics/analytics_service.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provisions and stores the 256-bit symmetric key used to encrypt the local
/// offline-first drift database (`shamba.sqlite`) with SQLCipher.
///
/// The key is generated once per device — 32 cryptographically-secure random
/// bytes, hex-encoded — and persisted in the platform keystore/keychain via
/// [FlutterSecureStorage], using the same options `UserStorageService` uses.
/// It never rides Android auto-backup (`allowBackup=false`, set in Phase
/// 5.0) and never leaves the device.
///
/// This service does no I/O until [getOrCreateKey] or [deleteKey] is called.
/// Callers on the offline DB's open path MUST only invoke it lazily, inside
/// the database's `LazyDatabase` opener, so that with the offline flag off
/// (rule zero) nothing here ever runs.
///
/// If secure storage is genuinely unavailable on a device (throws), this
/// degrades to `shared_preferences` rather than locking the user out of the
/// app entirely — the same deliberate weaker-posture tradeoff already
/// documented for `UserStorageService` (audit S4-C2). That fallback is made
/// visible: a `secure_storage_fallback` analytics event fires and a warning
/// is logged, mirroring `UserStorageService._writeString`.
class DbKeyService {
  DbKeyService({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  /// The key under which the encryption key itself is stored. Not a secret
  /// value — just the storage key/label.
  static const String _keyName = 'db_encryption_key';

  /// 256 bits.
  static const int _keyLengthBytes = 32;

  final FlutterSecureStorage _secureStorage;

  /// Returns the stable 256-bit (32-byte, hex-encoded) key used to encrypt
  /// the local database, generating and persisting one on first use. Every
  /// later call — same device, same install — returns the same key.
  Future<String> getOrCreateKey() async {
    final existing = await _readString(_keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _generateKeyHex();
    await _writeString(_keyName, generated);
    return generated;
  }

  /// Deletes the persisted key from both the secure store and its
  /// shared-preferences fallback.
  ///
  /// Used by the key-loss recovery path: once the key backing an encrypted
  /// database is gone (or wrong), the database it protects is unreadable
  /// anyway, so the key is discarded and a fresh one is generated for the
  /// fresh database that replaces it.
  Future<void> deleteKey() async {
    try {
      await _secureStorage.delete(key: _keyName);
    } catch (e) {
      appLogger.warning(
        LogCategory.general,
        'Secure storage delete failed for $_keyName',
        e,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
  }

  String _generateKeyHex() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < _keyLengthBytes; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> _writeString(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      return;
    } catch (e) {
      appLogger.warning(
        LogCategory.general,
        'Secure storage write failed for $key',
        e,
      );
      // Deliberate degrade-don't-lock-out tradeoff (audit S4-C2), mirrored
      // from UserStorageService: fall back to shared_preferences so the app
      // still opens, but make the weaker posture visible.
      try {
        GetIt.instance<AnalyticsService>().track(
          'secure_storage_fallback',
          metadata: {'key': key},
        );
      } catch (_) {
        // analytics unavailable (tests, early boot) — the log line stands
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _readString(String key) async {
    try {
      final secureValue = await _secureStorage.read(key: key);
      if (secureValue != null) return secureValue;
    } catch (e) {
      appLogger.warning(
        LogCategory.general,
        'Secure storage read failed for $key',
        e,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
