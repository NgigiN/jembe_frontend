import '../../domain/entities/animal_type.dart';

class AnimalTypeModel extends AnimalType {
  const AnimalTypeModel({
    required super.id,
    required super.userId,
    required super.name,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AnimalTypeModel.fromJson(Map<String, dynamic> json) {
    final notesValue = json['notes'] ?? json['Notes'];

    return AnimalTypeModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      notes: notesValue != null ? notesValue.toString() : null,
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
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  factory AnimalTypeModel.create({
    required String userId,
    required String name,
    String? notes,
  }) {
    final now = DateTime.now();
    return AnimalTypeModel(
      id: '',
      userId: userId,
      name: name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}

