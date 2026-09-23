import 'package:adaptive_scaffold_plus/adaptive_scaffold_plus.dart';
import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WebConsoleShell extends StatelessWidget {
  const WebConsoleShell({required this.child, super.key});
  final Widget child;

  static const Map<String, AdaptiveDestination> _allDestinations = {
    WebRoutePath.dashboard: AdaptiveDestination(
      icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard',
    ),
    WebRoutePath.feed: AdaptiveDestination(
      icon: Icons.dynamic_feed_outlined, selectedIcon: Icons.dynamic_feed, label: 'Feed',
    ),
    WebRoutePath.members: AdaptiveDestination(
      icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Members',
    ),
    WebRoutePath.reports: AdaptiveDestination(
      icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Reports',
    ),
  };

  static const Set<String> _staffOnlyRoutes = {WebRoutePath.dashboard, WebRoutePath.reports};

  static List<String> _routesFor(FarmRole? role) =>
      _allDestinations.keys.where((route) => role == null || role.isStaff || !_staffOnlyRoutes.contains(route)).toList();

  @override
  Widget build(BuildContext context) {
    final farmState = context.watch<FarmBloc>().state;
    final role = farmState is FarmLoaded ? farmState.currentRole : null;
    final currentFarmName = _currentFarmName(farmState);
    final routes = _routesFor(role);
    final destinations = routes.map((route) => _allDestinations[route]!).toList();
    final index = _calculateIndex(context, routes);
    return AdaptiveScaffoldPlus(
      key: ValueKey(index),
      appBar: AppBar(
        title: Text(currentFarmName ?? 'Shamba+'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch farm',
            onPressed: () => context.go(WebRoutePath.farmsList),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthBloc>().add(LogoutEvent()),
          ),
        ],
      ),
      destinations: destinations,
      initialIndex: index,
      onDestinationSelected: (i) => context.go(routes[i]),
      body: (_) => child,
    );
  }

  String? _currentFarmName(FarmState state) {
    if (state is! FarmLoaded || state.currentFarmId == null) return null;
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId) return farm.name;
    }
    return null;
  }

  int _calculateIndex(BuildContext context, List<String> routes) {
    final uri = GoRouterState.of(context).uri.toString();
    for (var i = routes.length - 1; i >= 0; i--) {
      if (uri.startsWith(routes[i])) return i;
    }
    return 0;
  }
}
