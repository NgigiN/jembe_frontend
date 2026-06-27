import 'package:equatable/equatable.dart';

abstract class CostCategoryEvent extends Equatable {
  const CostCategoryEvent();

  @override
  List<Object?> get props => [];
}

class GetCostCategoriesEvent extends CostCategoryEvent {
  const GetCostCategoriesEvent({this.type, this.category});
  final String? type;
  final String? category;

  @override
  List<Object?> get props => [type, category];
}

class AddCostCategoryEvent extends CostCategoryEvent {
  const AddCostCategoryEvent({
    required this.name,
    required this.type,
    required this.category,
  });
  final String name;
  final String type;
  final String category;

  @override
  List<Object?> get props => [name, type, category];
}

class DeleteCostCategoryEvent extends CostCategoryEvent {
  const DeleteCostCategoryEvent({
    required this.id,
    required this.category,
  });
  final String id;
  final String category;

  @override
  List<Object?> get props => [id, category];
}
