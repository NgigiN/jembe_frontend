import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/farms/presentation/widgets/farm_switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Opens the console's farm picker and applies the choice.
///
/// Shares [FarmSwitcherSheet] with mobile so the two surfaces cannot drift,
/// but presents it as a centered dialog: a bottom sheet is the wrong gesture
/// at desktop width, and the sidebar tile that opens this sits at the top
/// left, nowhere near the bottom of the window.
///
/// The sidebar tile used to navigate to the farms page instead, which made
/// switching a trip to a settings screen rather than a change of context.
/// Selecting here dispatches [SwitchFarm], and `FarmScopedBlocs` rebuilds
/// the console's farm-scoped blocs so the page behind the dialog reloads.
///
/// There is no create-farm route on the console, so the picker shows only
/// the Manage action.
Future<void> showConsoleFarmSwitcher(BuildContext context) async {
  final farmBloc = context.read<FarmBloc>();
  final state = farmBloc.state;
  if (state is! FarmLoaded) return;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final chosen = await showDialog<Farm>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 460),
        child: FarmSwitcherSheet(
          farms: state.farms,
          currentFarmId: state.currentFarmId,
          onSelect: (farm) => Navigator.of(dialogContext).pop(farm),
          onManage: () {
            Navigator.of(dialogContext).pop();
            router.go(WebRoutePath.farmsList);
          },
        ),
      ),
    ),
  );

  if (chosen == null) return;
  farmBloc.add(SwitchFarm(chosen.id));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Switched to ${chosen.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
}
