import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/repositories/cost_category_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CostCategoryBloc extends Bloc<CostCategoryEvent, CostCategoryState> {
  CostCategoryBloc({required this.repository}) : super(CostCategoryInitial()) {
    on<GetCostCategoriesEvent>(_onGetCostCategories);
    on<AddCostCategoryEvent>(_onAddCostCategory);
    on<DeleteCostCategoryEvent>(_onDeleteCostCategory);
  }
  final CostCategoryRepository repository;

  Future<void> _onGetCostCategories(
    GetCostCategoriesEvent event,
    Emitter<CostCategoryState> emit,
  ) async {
    emit(const CostCategoryLoading());
    final result = await repository.getCostCategories(
      type: event.type,
      category: event.category,
    );

    result.fold(
      (failure) => emit(CostCategoryError(resolveFailureMessage(failure, 'Failed to load categories'))),
      (categories) => emit(CostCategoryLoaded(categories)),
    );
  }

  Future<void> _onAddCostCategory(
    AddCostCategoryEvent event,
    Emitter<CostCategoryState> emit,
  ) async {
    final currentCategories = state.categories;
    emit(CostCategoryLoading(categories: currentCategories));
    final result = await repository.addCostCategory(
      name: event.name,
      type: event.type,
      category: event.category,
    );

    result.fold(
      (failure) => emit(
        CostCategoryError(resolveFailureMessage(failure, 'Failed to save category'), categories: currentCategories),
      ),
      (success) {
        emit(CostCategoryAdded(categories: currentCategories));
        // Reload categories after adding to get the full list with IDs
        add(GetCostCategoriesEvent(category: event.category));
      },
    );
  }

  Future<void> _onDeleteCostCategory(
    DeleteCostCategoryEvent event,
    Emitter<CostCategoryState> emit,
  ) async {
    final currentCategories = state.categories;
    emit(CostCategoryLoading(categories: currentCategories));
    final result = await repository.deleteCostCategory(event.id);

    result.fold(
      (failure) => emit(
        CostCategoryError(resolveFailureMessage(failure, 'Failed to save category'), categories: currentCategories),
      ),
      (_) {
        emit(CostCategoryDeleted(categories: currentCategories));
        add(GetCostCategoriesEvent(category: event.category));
      },
    );
  }
}
