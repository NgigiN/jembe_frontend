import 'package:equatable/equatable.dart';
import '../../domain/entities/cost_category.dart';

abstract class CostCategoryState extends Equatable {
  final List<CostCategory> categories;
  const CostCategoryState({this.categories = const []});

  @override
  List<Object?> get props => [categories];
}

class CostCategoryInitial extends CostCategoryState {}

class CostCategoryLoading extends CostCategoryState {
  const CostCategoryLoading({super.categories});
}

class CostCategoryLoaded extends CostCategoryState {
  const CostCategoryLoaded(List<CostCategory> categories) : super(categories: categories);

  @override
  List<Object?> get props => [categories];
}

class CostCategoryError extends CostCategoryState {
  final String message;

  const CostCategoryError(this.message, {super.categories});

  @override
  List<Object?> get props => [message, categories];
}

class CostCategoryAdded extends CostCategoryState {
  const CostCategoryAdded({super.categories});
}
