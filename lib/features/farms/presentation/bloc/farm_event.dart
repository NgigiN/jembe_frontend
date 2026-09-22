import 'package:equatable/equatable.dart';

abstract class FarmEvent extends Equatable {
  const FarmEvent();
  @override
  List<Object?> get props => [];
}

/// Loads farm state from local cache, falling back to a live refresh when
/// nothing is cached yet (e.g. an already-logged-in device upgrading to
/// this release for the first time — spec §8).
class LoadFarms extends FarmEvent {}

/// Refetches `GET /farms` and updates both storage and state. Fired on app
/// resume/launch (Task 24) and after farm-management actions.
class RefreshFarms extends FarmEvent {}

/// Switches the current farm, persists the selection, and kicks a
/// background resync scoped to the new farm.
class SwitchFarm extends FarmEvent {
  const SwitchFarm(this.farmId);
  final int farmId;

  @override
  List<Object?> get props => [farmId];
}
