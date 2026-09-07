import 'package:equatable/equatable.dart';

abstract class TrashEvent extends Equatable {
  @override
  List<Object> get props => [];
}

/// Loads (or reloads, e.g. on pull-to-refresh) the full trash list.
class LoadTrashEvent extends TrashEvent {}

/// Restores one item. On success it is removed from `TrashLoaded.items`; on
/// a 409 it stays, and the conflict message is surfaced instead (Phase 8
/// A3/B2 — see `TrashBloc`).
class RestoreItemEvent extends TrashEvent {
  RestoreItemEvent({required this.entity, required this.id});
  final String entity;
  final String id;

  @override
  List<Object> get props => [entity, id];
}
