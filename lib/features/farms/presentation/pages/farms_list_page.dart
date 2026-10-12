import 'package:farm_tracker/core/navigation/app_route_path.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The farm list, which drives the bloc it reads from.
///
/// It used to be a StatelessWidget that rendered a bare spinner for every
/// state other than [FarmLoaded], and dispatched nothing. The app's only
/// `LoadFarms` fires once in `main()` when the provider is built, so if that
/// call had failed or not finished — a cold start, a fresh install, a slow
/// network — this page spun forever. No retry, no message, and the
/// `RefreshIndicator` that could have rescued it sat inside the loaded branch,
/// unreachable precisely when it was needed.
///
/// It was reported as "loaded forever" on a freshly installed build, and it
/// cleared itself only because resuming the app dispatches `RefreshFarms`,
/// which is why it looked intermittent rather than broken.
///
/// A page that needs data asks for it. Anything else is hoping somebody else
/// did.
class FarmsListPage extends StatefulWidget {
  const FarmsListPage({super.key});

  @override
  State<FarmsListPage> createState() => _FarmsListPageState();
}

class _FarmsListPageState extends State<FarmsListPage> {
  @override
  void initState() {
    super.initState();
    // Only when there is nothing to show. A farm list already loaded is still
    // good, and refetching it on every visit would cost a request to render
    // what is already on screen.
    final bloc = context.read<FarmBloc>();
    if (bloc.state is! FarmLoaded) {
      bloc.add(LoadFarms());
    }
  }

  void _retry() => context.read<FarmBloc>().add(LoadFarms());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Farms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Farm',
            onPressed: () => context.push(AppRoutePath.createFarm),
          ),
        ],
      ),
      body: BlocBuilder<FarmBloc, FarmState>(
        builder: (context, state) {
          if (state is FarmError) {
            return EntityErrorView(message: state.message, onRetry: _retry);
          }
          if (state is! FarmLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<FarmBloc>().add(RefreshFarms());
              await context.read<FarmBloc>().stream.firstWhere(
                (s) => s is FarmLoaded || s is FarmError,
              );
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.farms.length,
              itemBuilder: (context, index) {
                final farm = state.farms[index];
                final isCurrent = farm.id == state.currentFarmId;
                return ListTile(
                  title: Text(farm.name),
                  subtitle: Text(farm.role.wireValue),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Manage',
                        onPressed: () => context.push(AppRoutePath.farmManage),
                      ),
                    ],
                  ),
                  onTap: isCurrent
                      ? null
                      : () => context.read<FarmBloc>().add(SwitchFarm(farm.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
