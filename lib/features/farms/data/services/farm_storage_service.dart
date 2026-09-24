import 'dart:convert';

import 'package:farm_tracker/features/farms/data/models/farm_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the joined-farms list, the backend's default farm, and the
/// device's explicitly-selected current farm.
///
/// Plain `SharedPreferences` only (unlike `UserStorageService`, which also
/// uses secure storage for the auth token) — nothing cached here is
/// credential-like.
class FarmStorageService {
  static const String _farmsKey = 'farms_data';
  static const String _defaultFarmIdKey = 'default_farm_id';
  static const String _currentFarmIdKey = 'current_farm_id';

  static Future<void> saveFarms(List<Farm> farms, {int? defaultFarmId}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      farms
          .map(
            (f) => FarmModel(
              id: f.id,
              name: f.name,
              location: f.location,
              fiscalYearStartMonth: f.fiscalYearStartMonth,
              ownerUserId: f.ownerUserId,
              successorUserId: f.successorUserId,
              maxMembers: f.maxMembers,
              role: f.role,
              memberCount: f.memberCount,
              isDefault: f.isDefault,
            ).toJson(),
          )
          .toList(),
    );
    await prefs.setString(_farmsKey, encoded);
    if (defaultFarmId != null) {
      await prefs.setInt(_defaultFarmIdKey, defaultFarmId);
    }
  }

  static Future<List<Farm>> getFarms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_farmsKey);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((json) => FarmModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  static Future<int?> getDefaultFarmId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultFarmIdKey);
  }

  static Future<void> setCurrentFarmId(int farmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentFarmIdKey, farmId);
  }

  static Future<int?> getCurrentFarmId() async {
    final prefs = await SharedPreferences.getInstance();
    final explicit = prefs.getInt(_currentFarmIdKey);
    if (explicit != null) return explicit;
    return getDefaultFarmId();
  }

  static Future<FarmRole?> getCurrentRole() async {
    final currentId = await getCurrentFarmId();
    if (currentId == null) return null;
    final farms = await getFarms();
    for (final farm in farms) {
      if (farm.id == currentId) return farm.role;
    }
    return null;
  }

  static Future<void> clearFarmData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_farmsKey);
    await prefs.remove(_defaultFarmIdKey);
    await prefs.remove(_currentFarmIdKey);
  }
}
