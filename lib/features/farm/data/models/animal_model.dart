import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

class AnimalModel extends Animal {
  const AnimalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.animalTypeId,
    required super.herdId,
    required super.birthDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AnimalModel.create({
    required String userId,
    required String name,
    required String animalTypeId,
    required String herdId,
    required DateTime birthDate,
  }) {
    final now = DateTime.now();
    return AnimalModel(
      id: '',
      userId: userId,
      name: name,
      animalTypeId: animalTypeId,
      herdId: herdId,
      birthDate: birthDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    return AnimalModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      animalTypeId: (json['animal_type_id'] ?? json['AnimalTypeID'] ?? '').toString(),
      herdId: (json['herd_id'] ?? json['HerdID'] ?? '').toString(),
      birthDate: _parseDate(json['birth_date'] ?? json['BirthDate']),
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
      'name': name,
      'animal_type_id': int.tryParse(animalTypeId) ?? animalTypeId,
      'herd_id': int.tryParse(herdId) ?? herdId,
      'birth_date': birthDate.toUtc().toIso8601String(),
    };
  }
}
