import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/core/offline/widgets/offline_banner.dart';
import 'package:farm_tracker/core/offline/widgets/sync_status_indicator.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthInitial) {
          context.go(AppRoutePath.googleLogin);
        }
      },
      child: Scaffold(
        body: Column(
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _calculateIndex(context),
          onDestinationSelected: (index) => _onTabSelected(index, context),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.eco_outlined),
              selectedIcon: Icon(Icons.eco),
              label: 'Plants',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets),
              label: 'Animals',
            ),
            NavigationDestination(
              icon: Icon(Icons.monetization_on_outlined),
              selectedIcon: Icon(Icons.monetization_on),
              label: 'Revenue',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  int _calculateIndex(BuildContext context) {
    final uri = GoRouterState.of(context).uri.toString();
    if (uri.startsWith('/analytics')) return 1;
    if (uri.startsWith('/animals')) return 2;
    if (uri.startsWith('/revenue')) return 3;
    if (uri.startsWith('/settings')) return 4;
    return 0;
  }

  void _onTabSelected(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/analytics');
      case 2:
        context.go('/animals');
      case 3:
        context.go('/revenue');
      case 4:
        context.go('/settings');
    }
  }
}
