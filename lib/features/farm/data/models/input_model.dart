import '../../domain/entities/input.dart';

class InputModel extends Input {
  const InputModel({
    required super.id,
    required super.seasonId,
    required super.landId,
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
      id: json['id'],
      seasonId: json['season_id'],
      landId: json['land_id'] ?? '',
      type: json['type'],
      quantity: json['quantity']?.toDouble(),
      cost: json['cost'].toDouble(),
      date: _parseDate(json['date']),
      notes: json['notes'],
      createdAt: _parseDate(json['created']),
      updatedAt: _parseDate(json['updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season_id': seasonId,
      'land_id': landId,
      'type': type,
      'quantity': quantity,
      'cost': cost,
      'date': date.toIso8601String(),
      'notes': notes,
      'created': createdAt.toIso8601String(),
      'updated': updatedAt.toIso8601String(),
    };
  }

  factory InputModel.create({
    required String seasonId,
    required String landId,
    required String type,
    double? quantity,
    required double cost,
    required DateTime date,
    String? notes,
  }) {
    final now = DateTime.now();
    return InputModel(
      id: '', // Will be set by the server
      seasonId: seasonId,
      landId: landId,
      type: type,
      quantity: quantity,
      cost: cost,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  static DateTime _parseDate(String dateString) {
    // Handle PocketBase date format: "2025-08-02 00:00:00.000Z"
    // Replace space with 'T' to make it ISO 8601 compliant
    final normalizedDate = dateString.replaceFirst(' ', 'T');
    return DateTime.parse(normalizedDate);
  }
}
