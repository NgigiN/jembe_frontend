import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/cost_category.dart';
import '../../domain/usecases/get_cost_categories.dart';
import '../../domain/usecases/add_cost_category.dart';
import 'cost_category_event.dart';
import 'cost_category_state.dart';

class CostCategoryBloc extends Bloc<CostCategoryEvent, CostCategoryState> {
  final GetCostCategories getCostCategories;
  final AddCostCategory addCostCategory;

  CostCategoryBloc({
    required this.getCostCategories,
    required this.addCostCategory,
  }) : super(CostCategoryInitial()) {
    on<GetCostCategoriesEvent>(_onGetCostCategories);
    on<AddCostCategoryEvent>(_onAddCostCategory);
  }

  Future<void> _onGetCostCategories(
    GetCostCategoriesEvent event,
    Emitter<CostCategoryState> emit,
  ) async {
    emit(CostCategoryLoading());
    final result = await getCostCategories(
      GetCostCategoriesParams(type: event.type, category: event.category),
    );

    result.fold(
      (failure) => emit(CostCategoryError(failure.message)),
      (categories) => emit(CostCategoryLoaded(categories)),
    );
  }

  Future<void> _onAddCostCategory(
    AddCostCategoryEvent event,
    Emitter<CostCategoryState> emit,
  ) async {
    final currentCategories = state.categories;
    emit(CostCategoryLoading(categories: currentCategories));
    final result = await addCostCategory(
      AddCostCategoryParams(
        name: event.name,
        type: event.type,
        category: event.category,
      ),
    );

    result.fold(
      (failure) => emit(CostCategoryError(failure.message, categories: currentCategories)),
      (success) {
        emit(CostCategoryAdded(categories: currentCategories));
        // Reload categories after adding to get the full list with IDs
        add(GetCostCategoriesEvent(type: event.type, category: event.category));
      },
    );
  }
}
