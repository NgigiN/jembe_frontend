import 'package:adaptive_scaffold_plus/adaptive_scaffold_plus.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/offline/widgets/offline_banner.dart';
import 'package:farm_tracker/core/offline/widgets/sync_status_indicator.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({required this.child, super.key});
  final Widget child;

  static const Map<String, AdaptiveDestination> _allDestinations = {
    '/': AdaptiveDestination(icon: Icons.eco_outlined, selectedIcon: Icons.eco, label: 'Plants'),
    AppRoutePath.analytics: AdaptiveDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Analytics',
    ),
    AppRoutePath.animals: AdaptiveDestination(icon: Icons.pets_outlined, selectedIcon: Icons.pets, label: 'Animals'),
    AppRoutePath.revenue: AdaptiveDestination(
      icon: Icons.monetization_on_outlined,
      selectedIcon: Icons.monetization_on,
      label: 'Revenue',
    ),
    AppRoutePath.settingsPage: AdaptiveDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  };

  /// Routes only staff (owner/manager) see. A worker's shell drops these.
  static const Set<String> _staffOnlyRoutes = {AppRoutePath.analytics, AppRoutePath.revenue};

  /// A null role (farms not loaded yet, or an error) shows every
  /// destination — the same behavior this shell had before roles existed —
  /// rather than flashing a reduced shell during the brief window before
  /// FarmBloc resolves.
  static List<String> _routesFor(FarmRole? role) =>
      _allDestinations.keys.where((route) => role == null || role.isStaff || !_staffOnlyRoutes.contains(route)).toList();

  @override
  Widget build(BuildContext context) {
    final farmState = context.watch<FarmBloc>().state;
    final role = farmState is FarmLoaded ? farmState.currentRole : null;
    final routes = _routesFor(role);
    final destinations = routes.map((route) => _allDestinations[route]!).toList();
    final index = _calculateIndex(context, routes);
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial) {
          context.go(AppRoutePath.googleLogin);
        }
      },
      // Keyed on the router-resolved index: AdaptiveScaffoldPlus only reads
      // its initialIndex once in initState (no didUpdateWidget - verified by
      // reading its source during planning), so a route change from
      // anywhere other than tapping a destination here (a deep link, the
      // back button, a context.go() elsewhere) would leave the wrong tab
      // highlighted unless the whole widget remounts. The ValueKey forces
      // that remount in lockstep with every index change.
      child: AdaptiveScaffoldPlus(
        key: ValueKey(index),
        destinations: destinations,
        initialIndex: index,
        onDestinationSelected: (i) => _onTabSelected(i, context, routes),
        body: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Self-hides (SizedBox.shrink()) when OfflineConfig.enabled is
            // false or the device is online, so this row contributes zero
            // height and the shell is byte-for-byte identical to today
            // flag-off. Sits above every tab's content (not inside it) so
            // the same banner shows regardless of which tab is active.
            const OfflineBanner(),
            // Self-hides (SizedBox.shrink()) when OfflineConfig.enabled is
            // false, so — like the banner above — this row collapses to
            // zero height flag-off (only the horizontal padding survives,
            // and it never paints anything without a visible child). A
            // single, always-in-the-same-place status row (rather than
            // per-tab app bar actions) keeps sync state visible no matter
            // which tab the user is on.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: SyncStatusIndicator(),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  int _calculateIndex(BuildContext context, List<String> routes) {
    final uri = GoRouterState.of(context).uri.toString();
    for (var i = routes.length - 1; i >= 0; i--) {
      final route = routes[i];
      if (route != '/' && uri.startsWith(route)) return i;
    }
    return routes.indexOf('/').clamp(0, routes.length - 1);
  }

  void _onTabSelected(int index, BuildContext context, List<String> routes) {
    context.go(routes[index]);
  }
}
