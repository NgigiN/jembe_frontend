import '../../domain/entities/crop.dart';

class CropModel extends Crop {
  const CropModel({
    required super.id,
    required super.userId,
    required super.name,
    super.variety,
    required super.createdAt,
    required super.updatedAt,
  });

  factory CropModel.fromJson(Map<String, dynamic> json) {
    return CropModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      variety: json['variety'],
      createdAt: DateTime.parse(json['created']),
      updatedAt: DateTime.parse(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'variety': variety,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }

  factory CropModel.create({
    required String userId,
    required String name,
    String? variety,
  }) {
    final now = DateTime.now();
    return CropModel(
      id: '', // Will be set by the server
      userId: userId,
      name: name,
      variety: variety,
      createdAt: now,
      updatedAt: now,
    );
  }
}
