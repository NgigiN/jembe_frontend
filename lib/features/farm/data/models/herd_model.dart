import 'package:farm_tracker/features/farm/domain/entities/herd.dart';

class HerdModel extends Herd {
  factory HerdModel.create({
    required String userId,
    required String name,
    required String animalTypeId,
    required String location,
    required int initialHeadCount,
  }) {
    final now = DateTime.now();
    return HerdModel(
      id: '',
      userId: userId,
      name: name,
      animalTypeId: animalTypeId,
      location: location,
      initialHeadCount: initialHeadCount,
      currentHeadCount: initialHeadCount,
      createdAt: now,
      updatedAt: now,
    );
  }
  const HerdModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.animalTypeId,
    required super.location,
    required super.initialHeadCount,
    required super.currentHeadCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory HerdModel.fromJson(Map<String, dynamic> json) {
    return HerdModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      animalTypeId: (json['animal_type_id'] ?? json['AnimalTypeID'] ?? '')
          .toString(),
      location: (json['location'] ?? json['Location'] ?? '').toString(),
      initialHeadCount: _parseInt(json['initial_head_count'] ?? json['InitialHeadCount']),
      currentHeadCount: _parseInt(json['current_head_count'] ?? json['CurrentHeadCount']),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
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
      'name': name,
      'animal_type_id': int.tryParse(animalTypeId) ?? animalTypeId,
      'location': location,
      'initial_head_count': initialHeadCount,
    };
  }
}
