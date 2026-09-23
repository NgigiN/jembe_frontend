import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/features/auth/data/models/user_storage_model.dart';
import 'package:farm_tracker/features/auth/data/services/user_storage_service.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:farm_tracker/features/auth/presentation/bloc/auth_event.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The console's frame: sidebar on the left, the routed page on the right
/// (DESIGN_SPEC §2).
///
/// Below [ConsoleMetrics.shellBreakpoint] the sidebar collapses to a 72px
/// icon rail. It stays a rail rather than becoming a bottom bar because
/// the console's seven destinations sit in two groups, and a bottom bar
/// would have to drop one group or the other.
class WebConsoleShell extends StatefulWidget {
  const WebConsoleShell({required this.child, super.key});

  final Widget child;

  @override
  State<WebConsoleShell> createState() => _WebConsoleShellState();
}

class _WebConsoleShellState extends State<WebConsoleShell> {
  /// Loaded once rather than per build: the signed-in user doesn't change
  /// while the shell is mounted, and the sidebar rebuilds on every farm
  /// state change.
  late final Future<UserStorageModel?> _user = UserStorageService.getUserData();

  @override
  Widget build(BuildContext context) {
    final farmState = context.watch<FarmBloc>().state;
    final role = farmState is FarmLoaded ? farmState.currentRole : null;
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: FutureBuilder<UserStorageModel?>(
        future: _user,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return LayoutBuilder(
            builder: (context, constraints) {
              // stretch, not the Row's default centre: a page whose content
              // is shorter than the window would otherwise float in the
              // middle of it instead of starting under the header.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConsoleSidebar(
                    location: location,
                    role: role,
                    farmName: _currentFarmName(farmState),
                    userName: user?.name ?? '',
                    userEmail: user?.email ?? '',
                    compact:
                        constraints.maxWidth < ConsoleMetrics.shellBreakpoint,
                    onNavigate: (route) => context.go(route),
                    onSwitchFarm: () => context.go(WebRoutePath.farmsList),
                    onSignOut: () =>
                        context.read<AuthBloc>().add(LogoutEvent()),
                  ),
                  Expanded(child: widget.child),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String? _currentFarmName(FarmState state) {
    if (state is! FarmLoaded || state.currentFarmId == null) return null;
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId) return farm.name;
    }
    return null;
  }
}

/// The role the shell resolved, for pages that need to vary by it without
/// re-deriving it from [FarmBloc] themselves.
FarmRole? consoleRoleOf(BuildContext context) {
  final state = context.watch<FarmBloc>().state;
  return state is FarmLoaded ? state.currentRole : null;
}
