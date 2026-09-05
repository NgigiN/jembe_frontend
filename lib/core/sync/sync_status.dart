import 'package:equatable/equatable.dart';

/// Coarse phase of the sync engine, surfaced to the UI.
enum SyncPhase {
  /// Not currently syncing (also the resting state after a clean pass).
  idle,

  /// A sync pass is in progress.
  syncing,

  /// The last pass hit a transient failure; a backoff retry is scheduled.
  error,
}

/// Immutable snapshot of the sync engine's state.
class SyncStatus extends Equatable {
  const SyncStatus({
    required this.phase,
    this.lastSyncedAt,
    this.pendingCount = 0,
  });

  final SyncPhase phase;

  /// When the last fully-successful pass completed, or null if none yet.
  final DateTime? lastSyncedAt;

  /// Outbox rows still awaiting sync (`state == 'pending'`).
  final int pendingCount;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    int? pendingCount,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }

  @override
  List<Object?> get props => [phase, lastSyncedAt, pendingCount];
}
