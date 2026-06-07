import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';

class InfrastructureModel extends Infrastructure {
  const InfrastructureModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.name,
    required super.location,
    required super.cost,
    required super.date,
    required super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InfrastructureModel.create({
    required String userId,
    required String type,
    required String name,
    required String location,
    required double cost,
    required DateTime date,
    String? notes,
  }) {
    final now = DateTime.now();
    return InfrastructureModel(
      id: '',
      userId: userId,
      type: type,
      name: name,
      location: location,
      cost: cost,
      date: date,
      notes: notes ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory InfrastructureModel.fromJson(Map<String, dynamic> json) {
    return InfrastructureModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      location: (json['location'] ?? json['Location'] ?? '').toString(),
      cost: _parseDouble(json['cost'] ?? json['Cost']),
      date: _parseDate(json['date'] ?? json['Date']),
      notes: (json['notes'] ?? json['Notes'] ?? '').toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
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
      'type': type,
      'name': name,
      'location': location,
      'cost': cost,
      'date': date.toUtc().toIso8601String(),
      'notes': notes,
    };
  }
}
