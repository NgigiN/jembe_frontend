import '../../domain/entities/revenue.dart';

class RevenueModel extends Revenue {
  const RevenueModel({
    required super.id,
    required super.userId,
    required super.source,
    required super.sourceId,
    required super.type,
    required super.quantity,
    required super.unitPrice,
    required super.total,
    required super.date,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory RevenueModel.fromJson(Map<String, dynamic> json) {
    final notesValue = json['notes'] ?? json['Notes'];

    return RevenueModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      source: (json['source'] ?? json['Source'] ?? '').toString(),
      sourceId: (json['source_id'] ?? json['SourceID'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      quantity: _parseDouble(json['quantity'] ?? json['Quantity']),
      unitPrice: _parseDouble(json['unit_price'] ?? json['UnitPrice']),
      total: _parseDouble(json['total'] ?? json['Total']),
      date: _parseDate(json['date'] ?? json['Date']),
      notes: notesValue != null ? notesValue.toString() : null,
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
      'source_id': int.tryParse(sourceId) ?? sourceId,
      'type': type,
      'quantity': quantity,
      'unit_price': unitPrice,
      'date': date.toUtc().toIso8601String(),
    };

    if (total > 0) {
      json['total'] = total;
    }

    if (notes != null && notes!.isNotEmpty) {
      json['notes'] = notes!;
    }

    return json;
  }

  factory RevenueModel.create({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    double? total,
    required DateTime date,
    String? notes,
  }) {
    final now = DateTime.now();
    final calculatedTotal = total ?? (quantity * unitPrice);
    return RevenueModel(
      id: '',
      userId: '',
      source: source,
      sourceId: sourceId,
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      total: calculatedTotal,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }
}

