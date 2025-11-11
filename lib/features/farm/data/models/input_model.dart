import '../../domain/entities/input.dart';

class InputModel extends Input {
  const InputModel({
    required super.id,
    required super.sourceType,
    required super.sourceId,
    super.animalId,
    required super.type,
    super.quantity,
    required super.cost,
    required super.date,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InputModel.fromJson(Map<String, dynamic> json) {
    return InputModel(
      id: json['id'].toString(),
      sourceType: json['source_type'] ?? 'plant',
      sourceId: json['source_id']?.toString() ?? '',
      animalId: json['animal_id'] != null && json['animal_id'] != 0
          ? (json['animal_id'] is int ? json['animal_id'] : int.tryParse(json['animal_id'].toString()))
          : null,
      type: json['type'],
      quantity: json['quantity']?.toDouble(),
      cost: json['cost']?.toDouble() ?? 0.0,
      date: _parseDate(json['date']),
      notes: json['notes'],
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_type': sourceType,
      'source_id': sourceId,
      'animal_id': animalId ?? 0,
      'type': type,
      'quantity': quantity,
      'cost': cost,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory InputModel.create({
    required String sourceType,
    required String sourceId,
    int? animalId,
    required String type,
    double? quantity,
    required double cost,
    required DateTime date,
    String? notes,
  }) {
    final now = DateTime.now();
    return InputModel(
      id: '',
      sourceType: sourceType,
      sourceId: sourceId,
      animalId: animalId,
      type: type,
      quantity: quantity,
      cost: cost,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }
}
