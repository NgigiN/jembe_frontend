import 'package:farm_tracker/features/farm/domain/entities/land.dart';

class LandModel extends Land {
  factory LandModel.create({
    required String userId,
    required String name,
    double? size,
    String? location,
    String? soilType,
    String? tenureType,
  }) {
    final now = DateTime.now();
    return LandModel(
      id: '', // Will be set by the server
      userId: userId,
      name: name,
      size: size,
      location: location,
      soilType: soilType,
      tenureType: tenureType,
      createdAt: now,
      updatedAt: now,
    );
  }
  const LandModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    super.size,
    super.location,
    super.soilType,
    super.tenureType,
  });

  factory LandModel.fromJson(Map<String, dynamic> json) {
    final sizeValue = json['Size'] ?? json['size'];
    final locationValue = json['Location'] ?? json['location'];
    final soilTypeValue = json['SoilType'] ?? json['soil_type'];
    final tenureTypeValue = json['TenureType'] ?? json['tenure_type'];

    return LandModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      size: sizeValue != null ? (sizeValue as num).toDouble() : null,
      location: locationValue?.toString(),
      soilType: soilTypeValue?.toString(),
      tenureType: tenureTypeValue?.toString(),
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
      'tenure_type': tenureType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
