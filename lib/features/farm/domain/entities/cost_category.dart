import 'package:equatable/equatable.dart';

class CostCategory extends Equatable {
  const CostCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.isDefault,
  });
  final String id;
  final String name;
  final String type; // 'plant' or 'animal'
  final String category; // 'activity' or 'input'
  final bool isDefault;

  @override
  List<Object?> get props => [id, name, type, category, isDefault];
}
