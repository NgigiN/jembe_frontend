import '../../domain/entities/plant.dart';

class PlantModel extends Plant {
  const PlantModel({
    required super.id,
    required super.userId,
    required super.name,
    super.variety,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    return PlantModel(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      name: json['name'],
      variety: json['variety'],
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
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
      'variety': variety,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PlantModel.create({
    required String userId,
    required String name,
    String? variety,
  }) {
    final now = DateTime.now();
    return PlantModel(
      id: '',
      userId: userId,
      name: name,
      variety: variety,
      createdAt: now,
      updatedAt: now,
    );
  }
}

