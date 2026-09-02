import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';

class CostCategoryModel extends CostCategory {
  const CostCategoryModel({
    required super.id,
    required super.name,
    required super.type,
    required super.category,
    required super.isDefault,
  });

  factory CostCategoryModel.fromJson(Map<String, dynamic> json) {
    return CostCategoryModel(
      id: (json['id'] ?? json['ID'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      category: (json['category'] ?? json['Category'] ?? '').toString(),
      isDefault:
          (json['is_default'] as bool?) ??
          (json['isDefault'] as bool?) ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'category': category,
      'is_default': isDefault,
    };
  }
}
