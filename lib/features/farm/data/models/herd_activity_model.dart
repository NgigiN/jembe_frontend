import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';

class HerdActivityModel extends HerdActivity {
  const HerdActivityModel({
    required super.id,
    required super.herdId,
    required super.activityType,
    required super.count,
    required super.date,
    required super.createdAt, super.notes,
  });

  factory HerdActivityModel.create({
    required String herdId,
    required String activityType,
    required int count,
    required DateTime date,
    String? notes,
  }) {
    return HerdActivityModel(
      id: '',
      herdId: herdId,
      activityType: activityType,
      count: count,
      date: date,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  factory HerdActivityModel.fromJson(Map<String, dynamic> json) {
    return HerdActivityModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      herdId: (json['herd_id'] ?? json['HerdID'] ?? '').toString(),
      activityType: (json['activity_type'] ?? json['ActivityType'] ?? '').toString(),
      count: _parseInt(json['count'] ?? json['Count']),
      date: _parseDate(json['date'] ?? json['Date']),
      // The backend stores and returns this field as `reason`.
      notes: (json['reason'] ?? json['Reason'] ?? '').toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
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
      'activity_type': activityType,
      'count': count,
      'date': date.toUtc().toIso8601String(),
      'reason': notes ?? '',
    };
  }
}
