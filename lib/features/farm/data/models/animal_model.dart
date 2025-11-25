import '../../domain/entities/animal.dart';

class AnimalModel extends Animal {
  const AnimalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    super.number,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    return AnimalModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: json['Name'] ?? json['name'] ?? '',
      type: json['Type'] ?? json['type'] ?? '',
      number: json['Number'] ?? json['number'],
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
      'type': type,
      'number': number,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AnimalModel.create({
    required String userId,
    required String name,
    required String type,
    int? number,
  }) {
    final now = DateTime.now();
    return AnimalModel(
      id: '',
      userId: userId,
      name: name,
      type: type,
      number: number,
      createdAt: now,
      updatedAt: now,
    );
  }
}

