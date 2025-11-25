import '../../domain/entities/land.dart';

class LandModel extends Land {
  const LandModel({
    required super.id,
    required super.userId,
    required super.name,
    super.size,
    super.location,
    super.soilType,
    required super.createdAt,
    required super.updatedAt,
  });

  factory LandModel.fromJson(Map<String, dynamic> json) {
    return LandModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: json['Name'] ?? json['name'] ?? '',
      size: (json['Size'] ?? json['size'])?.toDouble(),
      location: json['Location'] ?? json['location'],
      soilType: json['SoilType'] ?? json['soil_type'],
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
      'size': size,
      'location': location,
      'soil_type': soilType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LandModel.create({
    required String userId,
    required String name,
    double? size,
    String? location,
    String? soilType,
  }) {
    final now = DateTime.now();
    return LandModel(
      id: '', // Will be set by the server
      userId: userId,
      name: name,
      size: size,
      location: location,
      soilType: soilType,
      createdAt: now,
      updatedAt: now,
    );
  }
}
