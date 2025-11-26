import '../../domain/entities/season.dart';

class SeasonModel extends Season {
  const SeasonModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.plantId,
    required super.landId,
    required super.startDate,
    super.endDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    final endDateValue = json['EndDate'] ?? json['end_date'];
    return SeasonModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      plantId: (json['PlantID'] ?? json['plant_id'] ?? '').toString(),
      landId: (json['LandID'] ?? json['land_id'] ?? '').toString(),
      startDate: _parseDate(json['StartDate'] ?? json['start_date']),
      endDate: endDateValue != null && endDateValue.toString().isNotEmpty
          ? _parseDate(endDateValue)
          : null,
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'plant_id': plantId,
      'land_id': landId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SeasonModel.create({
    required String userId,
    required String name,
    required String plantId,
    required String landId,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    return SeasonModel(
      id: '',
      userId: userId,
      name: name,
      plantId: plantId,
      landId: landId,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    );
  }
}
