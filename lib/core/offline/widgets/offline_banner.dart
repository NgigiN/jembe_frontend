import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:flutter/material.dart';

/// A thin banner that tells the user the device is offline and that any
/// changes made will sync once connectivity returns.
///
/// Hidden (renders [SizedBox.shrink]) whenever [OfflineConfig.enabled] is
/// `false` — the offline pipeline is dark-shipped, so this indicator must be
/// invisible flag-off, byte-for-byte identical to today's UI — or whenever
/// the device is currently online. The flag check runs *before* the
/// connectivity service is ever touched, so flag-off builds never subscribe
/// to [ConnectivityService.onlineChanges] (and, in tests, never require it
/// to be stubbed or registered in DI).
class OfflineBanner extends StatelessWidget {
  /// Creates an [OfflineBanner].
  ///
  /// [connectivityService] is injectable so tests can supply a fake/mock;
  /// defaults to the DI singleton (resolved lazily, only when needed).
  const OfflineBanner({super.key, ConnectivityService? connectivityService})
    : _injected = connectivityService;

  final ConnectivityService? _injected;

  ConnectivityService get _connectivityService =>
      _injected ?? di.sl<ConnectivityService>();

  @override
  Widget build(BuildContext context) {
    if (!OfflineConfig.enabled) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: _connectivityService.onlineChanges,
      builder: (context, snapshot) {
        // Assume online (hidden) until the first connectivity event lands,
        // so the banner doesn't flash on initial build.
        final online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();

        final warning = context.statusColors.warning;
        return Material(
          color: warning,
          child: const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You're offline — changes will sync when you reconnect",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
