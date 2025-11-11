import '../../domain/entities/activity.dart';

class ActivityModel extends Activity {
  const ActivityModel({
    required super.id,
    required super.seasonId,
    required super.landId,
    required super.type,
    required super.date,
    required super.cost,
    super.details,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      seasonId: json['season_id'],
      landId: json['land_id'] ?? '',
      type: json['type'],
      date: _parseDate(json['date']),
      cost: json['cost']?.toDouble() ?? 0.0,
      details: json['details'],
      createdAt: _parseDate(json['created']),
      updatedAt: _parseDate(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season_id': seasonId,
      'land_id': landId,
      'type': type,
      'date': date.toIso8601String(),
      'cost': cost,
      'details': details,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }

  factory ActivityModel.create({
    required String seasonId,
    required String landId,
    required String type,
    required DateTime date,
    required double cost,
    String? details,
  }) {
    final now = DateTime.now();
    return ActivityModel(
      id: '', // Will be set by the server
      seasonId: seasonId,
      landId: landId,
      type: type,
      date: date,
      cost: cost,
      details: details,
      createdAt: now,
      updatedAt: now,
    );
  }

  static DateTime _parseDate(String dateString) {
    // Handle PocketBase date format: "2025-08-02 00:00:00.000Z"
    // Replace space with 'T' to make it ISO 8601 compliant
    final normalizedDate = dateString.replaceFirst(' ', 'T');
    return DateTime.parse(normalizedDate);
  }
}
