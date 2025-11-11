import '../services/user_storage_service.dart';

class UserUtils {
  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    return await UserStorageService.getUserId();
  }

  // Get current user token
  static Future<String?> getCurrentUserToken() async {
    return await UserStorageService.getToken();
  }

  // Get complete user data
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = await UserStorageService.getUserData();
    if (user != null) {
      return {
        'id': user.id,
        'email': user.email,
        'name': user.name,
        'first_name': user.name.split(' ').isNotEmpty ? user.name.split(' ')[0] : '',
        'last_name': user.name.split(' ').length > 1 ? user.name.split(' ').sublist(1).join(' ') : '',
        'farm_name': user.farmName,
        'location': user.location,
        'token': user.token,
      };
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    return await UserStorageService.isLoggedIn();
  }

  // Get user's farm name
  static Future<String?> getUserFarmName() async {
    final user = await UserStorageService.getUserData();
    return user?.farmName;
  }

  // Get user's name
  static Future<String?> getUserName() async {
    final user = await UserStorageService.getUserData();
    return user?.name;
  }

  // Get user's location
  static Future<String?> getUserLocation() async {
    final user = await UserStorageService.getUserData();
    return user?.location;
  }
}
