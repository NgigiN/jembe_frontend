import 'package:farm_tracker/features/farm/domain/entities/input.dart';

class InputModel extends Input {
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
  const InputModel({
    required super.id,
    required super.sourceType,
    required super.sourceId,
    required super.type,
    required super.cost,
    required super.date,
    required super.createdAt,
    required super.updatedAt,
    super.animalId,
    super.quantity,
    super.notes,
  });

  factory InputModel.fromJson(Map<String, dynamic> json) {
    final animalIdValue = json['AnimalID'] ?? json['animal_id'];
    final quantityValue = json['Quantity'] ?? json['quantity'];
    final costValue = json['Cost'] ?? json['cost'];
    final notesValue = json['Notes'] ?? json['notes'];

    return InputModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      sourceType: (json['SourceType'] ?? json['source_type'] ?? 'plant')
          .toString(),
      sourceId: (json['SourceID'] ?? json['source_id'] ?? '').toString(),
      animalId: animalIdValue != null && animalIdValue != 0
          ? (animalIdValue is int
                ? animalIdValue
                : int.tryParse(animalIdValue.toString()))
          : null,
      type: (json['Type'] ?? json['type'] ?? '').toString(),
      quantity: quantityValue != null
          ? (quantityValue as num).toDouble()
          : null,
      cost: costValue != null ? (costValue as num).toDouble() : 0.0,
      date: _parseDate(json['Date'] ?? json['date']),
      notes: notesValue?.toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
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

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }
}
