import 'package:equatable/equatable.dart';
import '../../domain/entities/cost_category.dart';

abstract class CostCategoryState extends Equatable {
  const CostCategoryState();

  @override
  List<Object?> get props => [];
}

class CostCategoryInitial extends CostCategoryState {}

class CostCategoryLoading extends CostCategoryState {}

class CostCategoryLoaded extends CostCategoryState {
  final List<CostCategory> categories;

  const CostCategoryLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class CostCategoryError extends CostCategoryState {
  final String message;

  const CostCategoryError(this.message);

  @override
  List<Object?> get props => [message];
}

class CostCategoryAdded extends CostCategoryState {}
