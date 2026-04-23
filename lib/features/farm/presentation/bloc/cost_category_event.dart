import 'package:equatable/equatable.dart';

abstract class CostCategoryEvent extends Equatable {
  const CostCategoryEvent();

  @override
  List<Object?> get props => [];
}

class GetCostCategoriesEvent extends CostCategoryEvent {
  final String? type;
  final String? category;

  const GetCostCategoriesEvent({this.type, this.category});

  @override
  List<Object?> get props => [type, category];
}

class AddCostCategoryEvent extends CostCategoryEvent {
  final String name;
  final String type;
  final String category;

  const AddCostCategoryEvent({
    required this.name,
    required this.type,
    required this.category,
  });

  @override
  List<Object?> get props => [name, type, category];
}
