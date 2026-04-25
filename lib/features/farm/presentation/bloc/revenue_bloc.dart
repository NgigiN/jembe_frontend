import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenues.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenues_params.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_revenue_by_id.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_revenue.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_revenue.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';

class RevenueBloc extends Bloc<RevenueEvent, RevenueState> {

  RevenueBloc({
    required this.getRevenues,
    required this.getRevenueById,
    required this.addRevenue,
    required this.updateRevenue,
    required this.deleteRevenue,
  }) : super(RevenueInitial()) {
    on<LoadRevenues>(_onLoadRevenues);
    on<AddRevenueEvent>(_onAddRevenue);
    on<UpdateRevenueEvent>(_onUpdateRevenue);
    on<DeleteRevenueEvent>(_onDeleteRevenue);
  }
  final GetRevenues getRevenues;
  final GetRevenueById getRevenueById;
  final AddRevenue addRevenue;
  final UpdateRevenue updateRevenue;
  final DeleteRevenue deleteRevenue;

  Future<void> _onLoadRevenues(
    LoadRevenues event,
    Emitter<RevenueState> emit,
  ) async {
    emit(RevenueLoading(revenues: state.revenues));

    final params = GetRevenuesParams(
      source: event.source,
      startDate: event.startDate,
      endDate: event.endDate,
    );

    final result = await getRevenues(params);

    result.fold(
      (failure) {
        var message = 'Failed to load revenues';
        if (failure is ServerFailure && failure.errorMessage != null) {
          message = failure.errorMessage!;
        }
        emit(RevenueError(message, revenues: state.revenues));
      },
      (revenues) => emit(RevenueLoaded(revenues: revenues)),
    );
  }


  Future<void> _onAddRevenue(
    AddRevenueEvent event,
    Emitter<RevenueState> emit,
  ) async {
    final currentRevenues = state.revenues;
    emit(RevenueLoading(revenues: currentRevenues));

    final params = AddRevenueParams(
      source: event.source,
      sourceId: event.sourceId,
      type: event.type,
      quantity: event.quantity,
      unitPrice: event.unitPrice,
      total: event.total,
      date: event.date,
      notes: event.notes,
    );

    final result = await addRevenue(params);

    result.fold(
      (failure) {
        var message = 'Failed to add revenue';
        if (failure is ServerFailure && failure.errorMessage != null) {
          message = failure.errorMessage!;
        }
        emit(RevenueError(message, revenues: currentRevenues));
      },
      (revenue) {
        final updatedList = List<Revenue>.from(currentRevenues)..add(revenue);
        emit(RevenueAdded(revenue: revenue, revenues: updatedList));
      },
    );
  }

  Future<void> _onUpdateRevenue(
    UpdateRevenueEvent event,
    Emitter<RevenueState> emit,
  ) async {
    final currentRevenues = state.revenues;
    emit(RevenueLoading(revenues: currentRevenues));

    final params = UpdateRevenueParams(
      id: event.id,
      source: event.source,
      sourceId: event.sourceId,
      type: event.type,
      quantity: event.quantity,
      unitPrice: event.unitPrice,
      total: event.total,
      date: event.date,
      notes: event.notes,
    );

    final result = await updateRevenue(params);

    result.fold(
      (failure) {
        var message = 'Failed to update revenue';
        if (failure is ServerFailure && failure.errorMessage != null) {
          message = failure.errorMessage!;
        }
        emit(RevenueError(message, revenues: currentRevenues));
      },
      (revenue) {
        final updatedList = List<Revenue>.from(currentRevenues);
        final index = updatedList.indexWhere((r) => r.id == revenue.id);
        if (index != -1) {
          updatedList[index] = revenue;
        }
        emit(RevenueUpdated(revenue: revenue, revenues: updatedList));
      },
    );
  }

  Future<void> _onDeleteRevenue(
    DeleteRevenueEvent event,
    Emitter<RevenueState> emit,
  ) async {
    final currentRevenues = state.revenues;
    emit(RevenueLoading(revenues: currentRevenues));

    final result = await deleteRevenue(event.id);

    result.fold(
      (failure) {
        var message = 'Failed to delete revenue';
        if (failure is ServerFailure && failure.errorMessage != null) {
          message = failure.errorMessage!;
        }
        emit(RevenueError(message, revenues: currentRevenues));
      },
      (_) {
        final updatedList = List<Revenue>.from(currentRevenues)
          ..removeWhere((r) => r.id == event.id);
        emit(RevenueDeleted(revenues: updatedList));
      },
    );
  }
}

