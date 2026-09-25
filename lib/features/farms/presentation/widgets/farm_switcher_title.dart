import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/farms/presentation/widgets/farm_switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The current farm's name, or `null` when no farm is resolved yet (first
/// launch, or a [FarmState] that isn't [FarmLoaded]).
String? currentFarmName(FarmState state) {
  if (state is! FarmLoaded) return null;
  for (final farm in state.farms) {
    if (farm.id == state.currentFarmId) return farm.name;
  }
  return null;
}

/// Whether a switcher is worth offering: a picker containing one farm is a
/// control that cannot do anything.
bool canSwitchFarm(FarmState state) =>
    state is FarmLoaded && state.farms.length > 1;

/// The app-bar title, as a pure view.
class FarmSwitcherTitleView extends StatelessWidget {
  const FarmSwitcherTitleView({
    required this.label,
    required this.canSwitch,
    required this.onTap,
    super.key,
  });

  final String label;

  /// Drives both the caret and the tap target — with one farm this renders
  /// as an ordinary, inert app-bar title.
  final bool canSwitch;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).appBarTheme.titleTextStyle,
    );
    if (!canSwitch) return text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 24),
          ],
        ),
      ),
    );
  }
}

/// App-bar title that doubles as the farm switcher.
///
/// Replaces a plain `Text('Plants')` on the top-level pages. Switching used
/// to live four taps deep — Plants, Settings, scroll, Farms, tap — which
/// made it feel like an administrative setting rather than the context every
/// screen is read through. Here it is two taps, and the farm name is visible
/// at all times.
///
/// [fallback] is the page's own name, shown until farms resolve so the app
/// bar is never blank on first launch.
class FarmSwitcherTitle extends StatelessWidget {
  const FarmSwitcherTitle({required this.fallback, super.key});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmBloc>().state;
    return FarmSwitcherTitleView(
      label: currentFarmName(state) ?? fallback,
      canSwitch: canSwitchFarm(state),
      onTap: () => showFarmSwitcherSheet(context),
    );
  }
}
