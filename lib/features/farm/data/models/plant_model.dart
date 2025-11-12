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
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: json['Name'] ?? json['name'] ?? '',
      variety: json['Variety'] ?? json['variety'],
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

