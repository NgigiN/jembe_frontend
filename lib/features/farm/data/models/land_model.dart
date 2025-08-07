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
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      size: json['size']?.toDouble(),
      location: json['location'],
      soilType: json['soil_type'],
      createdAt: DateTime.parse(json['created']),
      updatedAt: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'size': size,
      'location': location,
      'soil_type': soilType,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
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
