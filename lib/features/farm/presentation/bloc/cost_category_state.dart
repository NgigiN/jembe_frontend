import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';

abstract class CostCategoryState extends Equatable {
  const CostCategoryState({this.categories = const []});
  final List<CostCategory> categories;

  @override
  List<Object?> get props => [categories];
}

class CostCategoryInitial extends CostCategoryState {}

class CostCategoryLoading extends CostCategoryState {
  const CostCategoryLoading({super.categories});
}

class CostCategoryLoaded extends CostCategoryState {
  const CostCategoryLoaded(List<CostCategory> categories)
    : super(categories: categories);

  @override
  List<Object?> get props => [categories];
}

class CostCategoryError extends CostCategoryState {
  const CostCategoryError(this.message, {super.categories});
  final String message;

  @override
  List<Object?> get props => [message, categories];
}

class CostCategoryAdded extends CostCategoryState {
  const CostCategoryAdded({super.categories});
}
