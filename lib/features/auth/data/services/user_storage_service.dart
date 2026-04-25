import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';

class UserStorageService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static bool get _shouldUseSecureStorage => !kIsWeb;

  // Save user data to shared preferences
  static Future<void> saveUserData(UserStorageModel user) async {
    final serialized = jsonEncode(user.toJson());
    await _writeString(_userKey, serialized);
    await _writeString(_tokenKey, user.token);
    await _writeString(_userIdKey, user.id);
  }

  // Get user data from shared preferences
  static Future<UserStorageModel?> getUserData() async {
    final userJson = await _readString(_userKey);

    if (userJson != null) {
      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return UserStorageModel.fromJson(userMap);
      } catch (e) {
        appLogger.warning(
          LogCategory.auth,
          'Failed to parse cached user data',
          e,
        );
        return null;
      }
    }
    return null;
  }

  // Get token from shared preferences
  static Future<String?> getToken() async {
    final token = await _readString(_tokenKey);
    if (token != null && token.isNotEmpty) return token;
    final user = await getUserData();
    return user?.token;
  }

  // Get user ID from shared preferences
  static Future<String?> getUserId() async {
    final id = await _readString(_userIdKey);
    if (id != null && id.isNotEmpty) return id;
    final user = await getUserData();
    return user?.id;
  }

  // Check if user is logged in and session is valid (24 hours)
  static Future<bool> isLoggedIn() async {
    final user = await getUserData();
    if (user == null || user.token.isEmpty) {
      return false;
    }

    // Check if login was within the last 24 hours
    final now = DateTime.now();
    final loginTime = user.loginTime;
    final difference = now.difference(loginTime);

    // Session expires after 24 hours
    if (difference.inHours >= 24) {
      await clearUserData();
      return false;
    }

    return true;
  }

  // Get session remaining time in hours
  static Future<int> getSessionRemainingHours() async {
    final user = await getUserData();
    if (user == null) return 0;

    final now = DateTime.now();
    final difference = now.difference(user.loginTime);
    final remainingHours = 24 - difference.inHours;

    return remainingHours > 0 ? remainingHours : 0;
  }

  // Clear all user data (logout)
  static Future<void> clearUserData() async {
    if (_shouldUseSecureStorage) {
      await _secureStorage.delete(key: _userKey);
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userIdKey);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  // Update specific user fields
  static Future<void> updateUserField(String field, String value) async {
    final user = await getUserData();
    if (user != null) {
      final updatedUser = UserStorageModel(
        email: field == 'email' ? value : user.email,
        farmName: field == 'farm_name' ? value : user.farmName,
        id: field == 'id' ? value : user.id,
        location: field == 'location' ? value : user.location,
        name: field == 'name' ? value : user.name,
        token: field == 'token' ? value : user.token,
        loginTime: user.loginTime,
        pictureUrl: field == 'picture_url' ? value : user.pictureUrl,
      );
      await saveUserData(updatedUser);
    }
  }

  static Future<void> _writeString(String key, String value) async {
    if (_shouldUseSecureStorage) {
      try {
        await _secureStorage.write(key: key, value: value);
        return;
      } catch (e) {
        appLogger.warning(
          LogCategory.general,
          'Secure storage write failed for $key',
          e,
        );
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> _readString(String key) async {
    if (_shouldUseSecureStorage) {
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
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
}
