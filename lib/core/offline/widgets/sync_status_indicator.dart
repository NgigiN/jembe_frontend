import 'dart:async';

import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter/material.dart';

/// A compact sync-status readout — "Syncing…", "Synced 5m ago", "N pending"
/// or "Sync error" — with a small "Sync now" affordance that triggers
/// [SyncEngine.syncNow].
///
/// Hidden (renders [SizedBox.shrink]) whenever [OfflineConfig.enabled] is
/// `false`, following the same convention as `OfflineBanner`: the flag check
/// runs before the sync engine is ever touched, so flag-off builds never
/// read [SyncEngine.status] or subscribe to [SyncEngine.statusStream].
class SyncStatusIndicator extends StatelessWidget {
  /// Creates a [SyncStatusIndicator].
  ///
  /// [syncEngine] is injectable so tests can supply a fake/mock; defaults to
  /// the DI singleton (resolved lazily, only when needed). [now] is
  /// injectable so tests can pin "now" for deterministic relative-time text;
  /// defaults to [DateTime.now].
  const SyncStatusIndicator({
    super.key,
    SyncEngine? syncEngine,
    DateTime Function()? now,
  }) : _injected = syncEngine,
       _now = now ?? DateTime.now;

  final SyncEngine? _injected;
  final DateTime Function() _now;

  SyncEngine get _syncEngine => _injected ?? di.sl<SyncEngine>();

  @override
  Widget build(BuildContext context) {
    if (!OfflineConfig.enabled) return const SizedBox.shrink();

    final syncEngine = _syncEngine;
    return StreamBuilder<SyncStatus>(
      stream: syncEngine.statusStream,
      initialData: syncEngine.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? const SyncStatus(phase: SyncPhase.idle);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _label(status),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: _color(context, status)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.sync, size: 18),
              tooltip: 'Sync now',
              onPressed: () => unawaited(syncEngine.syncNow()),
            ),
          ],
        );
      },
    );
  }

  String _label(SyncStatus status) {
    switch (status.phase) {
      case SyncPhase.syncing:
        return 'Syncing…';
      case SyncPhase.error:
        return 'Sync error';
      case SyncPhase.idle:
        if (status.pendingCount > 0) {
          return '${status.pendingCount} pending';
        }
        final lastSyncedAt = status.lastSyncedAt;
        if (lastSyncedAt == null) return 'Not synced yet';
        return 'Synced ${_relativeLabel(lastSyncedAt)}';
    }
  }

  /// Renders the "Synced ..." suffix: "just now" for anything under a
  /// minute, otherwise "<n><unit> ago" at the coarsest unit that fits.
  String _relativeLabel(DateTime lastSyncedAt) {
    final diff = _now().difference(lastSyncedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color? _color(BuildContext context, SyncStatus status) {
    if (status.phase == SyncPhase.error) return context.statusColors.negative;
    return null;
  }
}
