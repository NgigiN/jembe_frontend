import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_storage_model.dart';

class UserStorageService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  // Save user data to shared preferences
  static Future<void> saveUserData(UserStorageModel user) async {
    final prefs = await SharedPreferences.getInstance();

    // Save complete user data as JSON
    await prefs.setString(_userKey, jsonEncode(user.toJson()));

    // Save token separately for easy access
    await prefs.setString(_tokenKey, user.token);

    // Save user ID separately for easy access
    await prefs.setString(_userIdKey, user.id);
  }

  // Get user data from shared preferences
  static Future<UserStorageModel?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      try {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return UserStorageModel.fromJson(userMap);
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }

  // Get token from shared preferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get user ID from shared preferences
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all user data (logout)
  static Future<void> clearUserData() async {
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
      );
      await saveUserData(updatedUser);
    }
  }
}
