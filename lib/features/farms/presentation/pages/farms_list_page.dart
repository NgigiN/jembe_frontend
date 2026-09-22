import 'package:farm_tracker/core/navigation/app_router.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FarmsListPage extends StatelessWidget {
  const FarmsListPage({super.key});

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
          if (state is! FarmLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<FarmBloc>().add(RefreshFarms());
              await context.read<FarmBloc>().stream.firstWhere((s) => s is FarmLoaded);
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
                        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
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
