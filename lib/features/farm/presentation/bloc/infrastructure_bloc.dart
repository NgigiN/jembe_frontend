import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_infrastructure.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InfrastructureBloc extends Bloc<InfrastructureEvent, InfrastructureState> {
  InfrastructureBloc({
    required this.getInfrastructure,
    required this.addInfrastructure,
    required this.updateInfrastructure,
    required this.deleteInfrastructure,
  }) : super(InfrastructureInitial()) {
    on<GetInfrastructuresEvent>(_onGetInfrastructures);
    on<AddInfrastructureEvent>(_onAddInfrastructure);
    on<UpdateInfrastructureEvent>(_onUpdateInfrastructure);
    on<DeleteInfrastructureEvent>(_onDeleteInfrastructure);
  }

  final GetInfrastructure getInfrastructure;
  final AddInfrastructure addInfrastructure;
  final UpdateInfrastructure updateInfrastructure;
  final DeleteInfrastructure deleteInfrastructure;

  Future<void> _onGetInfrastructures(
    GetInfrastructuresEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    emit(const InfrastructureLoading());
    final result = await getInfrastructure(NoParams());
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to load infrastructure'),
      )),
      (list) => emit(InfrastructureLoaded(list)),
    );
  }

  Future<void> _onAddInfrastructure(
    AddInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    final currentList = state.infrastructures;
    emit(InfrastructureLoading(infrastructures: currentList));
    final result = await addInfrastructure(
      event.type,
      event.name,
      event.location,
      event.cost,
      event.date,
      event.userId,
      event.notes,
    );
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to add infrastructure'),
        infrastructures: currentList,
      )),
      (item) {
        final updatedList = List<Infrastructure>.from(currentList)..add(item);
        emit(InfrastructureLoaded(updatedList, successMessage: 'Infrastructure added'));
      },
    );
  }

  Future<void> _onUpdateInfrastructure(
    UpdateInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    final currentList = state.infrastructures;
    emit(InfrastructureLoading(infrastructures: currentList));
    final result = await updateInfrastructure(
      event.id,
      event.type,
      event.name,
      event.location,
      event.cost,
      event.date,
      event.notes,
    );
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to update infrastructure'),
        infrastructures: currentList,
      )),
      (updatedItem) {
        final updatedList = currentList.map((item) {
          return item.id == updatedItem.id ? updatedItem : item;
        }).toList();
        emit(InfrastructureLoaded(updatedList, successMessage: 'Infrastructure updated'));
      },
    );
  }

  Future<void> _onDeleteInfrastructure(
    DeleteInfrastructureEvent event,
    Emitter<InfrastructureState> emit,
  ) async {
    final currentList = state.infrastructures;
    emit(InfrastructureLoading(infrastructures: currentList));
    final result = await deleteInfrastructure(event.id);
    result.fold(
      (failure) => emit(InfrastructureError(
        resolveFailureMessage(failure, 'Failed to delete infrastructure'),
        infrastructures: currentList,
      )),
      (_) {
        final updatedList = currentList.where((item) => item.id != event.id).toList();
        emit(InfrastructureLoaded(updatedList, successMessage: 'Infrastructure deleted'));
      },
    );
  }
}
