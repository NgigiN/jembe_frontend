import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';

abstract class TrashState extends Equatable {
  const TrashState({this.items = const []});
  final List<TrashItem> items;

  @override
  List<Object?> get props => [items];
}

class TrashInitial extends TrashState {
  const TrashInitial();
}

class TrashLoading extends TrashState {
  const TrashLoading({super.items});
}

class TrashLoaded extends TrashState {
  const TrashLoaded({
    required super.items,
    this.successMessage,
    this.conflictMessage,
  });

  /// Set for exactly one emission, immediately after a successful
  /// `RestoreItemEvent` — the page shows it as a success snackbar. `null`
  /// on the load-completed emission and on every other emission.
  final String? successMessage;

  /// Set for exactly one emission, immediately after a `RestoreItemEvent`
  /// that came back 409 (a still-tombstoned parent, or a cost_category
  /// collision — Phase 8 A3) — the page shows it as a distinct
  /// "couldn't restore" message. [items] is unchanged: the item stays in
  /// the trash list rather than being removed, since it was NOT restored.
  final String? conflictMessage;

  /// [items], grouped by [TrashItem.entity] and re-keyed in
  /// `trashEntities` order (`trash_item_model.dart`) — the section order
  /// `TrashPage` renders. An entity with no tombstones is simply absent
  /// (not an empty list) so the page can skip its header.
  Map<String, List<TrashItem>> get groupedByEntity {
    final grouped = <String, List<TrashItem>>{};
    for (final item in items) {
      (grouped[item.entity] ??= []).add(item);
    }
    return grouped;
  }

  @override
  List<Object?> get props => [items, successMessage, conflictMessage];
}

class TrashError extends TrashState {
  const TrashError(this.message, {super.items});
  final String message;

  @override
  List<Object?> get props => [message, items];
}
