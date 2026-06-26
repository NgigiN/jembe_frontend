import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';

class HarvestModel extends Harvest {
  factory HarvestModel.create({
    required String seasonId,
    required double quantity,
    required String unit,
    required DateTime date,
    String? notes,
  }) {
    final now = DateTime.now();
    return HarvestModel(
      id: '',
      seasonId: seasonId,
      quantity: quantity,
      unit: unit,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  const HarvestModel({
    required super.id,
    required super.seasonId,
    required super.quantity,
    required super.unit,
    required super.date,
    required super.createdAt,
    required super.updatedAt,
    super.notes,
    super.revenueId,
  });

  factory HarvestModel.fromJson(Map<String, dynamic> json) {
    final revenueIdValue = json['RevenueID'] ?? json['revenue_id'];

    return HarvestModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      seasonId: (json['SeasonID'] ?? json['season_id'] ?? '').toString(),
      quantity: ((json['Quantity'] ?? json['quantity'] ?? 0) as num).toDouble(),
      unit: (json['Unit'] ?? json['unit'] ?? '').toString(),
      date: _parseDate(json['Date'] ?? json['date']),
      notes: (json['Notes'] ?? json['notes'])?.toString(),
      revenueId: revenueIdValue != null && revenueIdValue != 0
          ? revenueIdValue.toString()
          : null,
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'season_id': int.tryParse(seasonId) ?? seasonId,
      'quantity': quantity,
      'unit': unit,
      'date': date.toUtc().toIso8601String(),
      'notes': notes ?? '',
      if (revenueId != null) 'revenue_id': int.tryParse(revenueId!) ?? revenueId,
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