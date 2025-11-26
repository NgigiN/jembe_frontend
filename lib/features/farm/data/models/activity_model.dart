import '../../domain/entities/activity.dart';

class ActivityModel extends Activity {
  const ActivityModel({
    required super.id,
    required super.sourceType,
    required super.sourceId,
    super.animalId,
    required super.type,
    super.details,
    required super.cost,
    required super.date,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final animalIdValue = json['AnimalID'] ?? json['animal_id'];
    final detailsValue = json['Details'] ?? json['details'];
    final costValue = json['Cost'] ?? json['cost'];
    final notesValue = json['Notes'] ?? json['notes'];

    return ActivityModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      sourceType: (json['SourceType'] ?? json['source_type'] ?? 'plant').toString(),
      sourceId: (json['SourceID'] ?? json['source_id'] ?? '').toString(),
      animalId: animalIdValue != null && animalIdValue != 0
          ? (animalIdValue is int ? animalIdValue : int.tryParse(animalIdValue.toString()))
          : null,
      type: (json['Type'] ?? json['type'] ?? '').toString(),
      details: detailsValue != null ? detailsValue.toString() : null,
      cost: costValue != null ? (costValue as num).toDouble() : 0.0,
      date: _parseDate(json['Date'] ?? json['date']),
      notes: notesValue != null ? notesValue.toString() : null,
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
      'details': details,
      'cost': cost,
      'date': date.toIso8601String().split('T')[0],
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ActivityModel.create({
    required String sourceType,
    required String sourceId,
    int? animalId,
    required String type,
    String? details,
    required double cost,
    required DateTime date,
    String? notes,
  }) {
    final now = DateTime.now();
    return ActivityModel(
      id: '',
      sourceType: sourceType,
      sourceId: sourceId,
      animalId: animalId,
      type: type,
      details: details,
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
