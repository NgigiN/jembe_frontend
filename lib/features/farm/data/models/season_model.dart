import '../../domain/entities/season.dart';

class SeasonModel extends Season {
  const SeasonModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.cropId,
    required super.landId,
    required super.startDate,
    super.endDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    return SeasonModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      cropId: json['crop_id'],
      landId: json['land_id'],
      startDate: _parseDate(json['start_date']),
      endDate:
          json['end_date'] != null && json['end_date'].toString().isNotEmpty
          ? _parseDate(json['end_date'])
          : null,
      createdAt: _parseDate(json['created']),
      updatedAt: _parseDate(json['updated']),
    );
  }

  static DateTime _parseDate(String dateString) {
    // Handle PocketBase date format: "2025-08-02 00:00:00.000Z"
    // Replace space with 'T' to make it ISO 8601 compliant
    final normalizedDate = dateString.replaceFirst(' ', 'T');
    return DateTime.parse(normalizedDate);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'crop_id': cropId,
      'land_id': landId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }

  factory SeasonModel.create({
    required String userId,
    required String name,
    required String cropId,
    required String landId,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return SeasonModel(
      id: '', // Will be set by the server
      userId: userId,
      name: name,
      cropId: cropId,
      landId: landId,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    );
  }
}
