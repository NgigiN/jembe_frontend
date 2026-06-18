import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_state.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.child});
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
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _calculateIndex(context),
          onDestinationSelected: (index) => _onTabSelected(index, context),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.eco), label: 'Plants'),
            NavigationDestination(
              icon: Icon(Icons.analytics),
              label: 'Analytics',
            ),
            NavigationDestination(icon: Icon(Icons.pets), label: 'Animals'),
            NavigationDestination(
              icon: Icon(Icons.monetization_on),
              label: 'Revenue',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
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
