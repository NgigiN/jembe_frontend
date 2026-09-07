import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';
import 'package:farm_tracker/features/farm/domain/repositories/trash_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Online-only "Recently deleted" bloc (Phase 8 B2): lists every
/// soft-deleted row (`GET /api/v1/trash`, A2) and restores one at a time
/// (`POST /api/v1/<entity>/:id/restore`, A3). Has no offline branch of its
/// own — the trash screen is reached only from Settings, and
/// `TrashRepositoryImpl` always talks straight to the network (see its
/// class docs on why restore can't work against the local mirror).
class TrashBloc extends Bloc<TrashEvent, TrashState> {
  TrashBloc({required this.repository}) : super(const TrashInitial()) {
    on<LoadTrashEvent>(_onLoad);
    on<RestoreItemEvent>(_onRestore);
  }
  final TrashRepository repository;

  Future<void> _onLoad(LoadTrashEvent event, Emitter<TrashState> emit) async {
    emit(TrashLoading(items: state.items));
    final result = await repository.getTrash();
    result.fold(
      (failure) => emit(
        TrashError(
          resolveFailureMessage(failure, 'Failed to load trash'),
          items: state.items,
        ),
      ),
      (items) => emit(TrashLoaded(items: items)),
    );
  }

  Future<void> _onRestore(
    RestoreItemEvent event,
    Emitter<TrashState> emit,
  ) async {
    final currentItems = state.items;
    final result = await repository.restore(
      entity: event.entity,
      id: event.id,
    );
    result.fold(
      (failure) {
        if (failure is ConflictFailure) {
          // Not restored: the item stays in the list, and the conflict
          // message (the backend's client-safe 409 text — a still-
          // tombstoned parent, or a cost_category collision) is surfaced
          // distinctly from a generic load/restore failure.
          emit(
            TrashLoaded(
              items: currentItems,
              conflictMessage: resolveFailureMessage(
                failure,
                'Could not restore — it conflicts with a live record',
              ),
            ),
          );
          return;
        }
        emit(
          TrashError(
            resolveFailureMessage(failure, 'Failed to restore item'),
            items: currentItems,
          ),
        );
      },
      (_) {
        final restored = currentItems.firstWhere(
          (i) => i.entity == event.entity && i.id == event.id,
          orElse: () =>
              TrashItem(entity: event.entity, id: event.id, label: 'Item'),
        );
        final remaining = currentItems
            .where((i) => !(i.entity == event.entity && i.id == event.id))
            .toList();
        emit(
          TrashLoaded(
            items: remaining,
            successMessage: '${restored.label} restored',
          ),
        );
      },
    );
  }
}
