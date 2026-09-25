import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';

/// Provides the farm-scoped blocs, and rebuilds every one of them from
/// scratch whenever the current farm changes.
///
/// ## Why this exists
/// A farm-scoped bloc (Land, Plant, Dashboard, ...) holds exactly one farm's
/// data and has no concept of that farm changing underneath it. Before this
/// widget, nothing in the app listened for a switch at all: `SwitchFarm`
/// wrote the new id to storage and emitted [FarmLoaded], and all sixteen
/// blocs carried on serving the previous farm's rows. Pages made it worse by
/// guarding their fetches on `state is! XLoaded`, so even navigating away and
/// back would not refetch — the stale state looked perfectly loaded.
///
/// The alternative was teaching all sixteen blocs to reset, and remembering
/// to teach the seventeenth. Keying their providers on the farm id costs no
/// per-bloc code and covers blocs that do not exist yet: a switch disposes
/// the old instances, builds fresh ones (every farm-scoped bloc is a
/// `registerFactory`, so each resolve is a new object), and remounts the
/// page, whose `initState` then refetches. Scoping is a per-request
/// `X-Farm-ID` header, so that refetch lands on the right farm with no
/// further plumbing.
///
/// ## Placement
/// Goes in `MaterialApp.router`'s `builder:`, which wraps the Navigator, so
/// pushed routes are covered too. `go_router` keeps its route stack in the
/// `GoRouter` instance rather than the widget tree, so the remount rebuilds
/// the page without losing the user's place.
///
/// Identity-scoped blocs (Auth, Farm, Theme, Profile, ...) MUST be provided
/// ABOVE this widget. They outlive a switch, and [FarmBloc] in particular is
/// the thing being listened to — providing it below would destroy the
/// listener on every switch.
///
/// ## Cost
/// The remount discards transient page state: scroll offsets, and a
/// half-filled form on a pushed route. That is intended — that state refers
/// to the farm the user just left.
class FarmScopedBlocs extends StatefulWidget {
  const FarmScopedBlocs({
    required this.providers,
    required this.child,
    super.key,
  });

  /// The farm-scoped providers. Rebuilt wholesale on every switch.
  final List<SingleChildWidget> providers;

  final Widget child;

  @override
  State<FarmScopedBlocs> createState() => _FarmScopedBlocsState();
}

class _FarmScopedBlocsState extends State<FarmScopedBlocs> {
  /// The farm the mounted subtree belongs to. `null` until the first
  /// [FarmLoaded] arrives.
  int? _farmId;

  /// Bumped only by a genuine switch, and used as the subtree's key.
  ///
  /// Deliberately NOT derived from [_farmId]. On a cold start the first
  /// [FarmLoaded] arrives a frame or two after the tree is built, so keying
  /// on the id directly would flip `null` -> `7` and remount every page that
  /// had just mounted — a doubled fetch on every launch, to land on the farm
  /// the app was already showing. Adopting the first id silently avoids that
  /// while still remounting on a real switch.
  int _generation = 0;

  static int? _currentFarmId(FarmState state) =>
      state is FarmLoaded ? state.currentFarmId : null;

  void _onFarmState(BuildContext context, FarmState state) {
    final id = _currentFarmId(state);
    // A null id means "not resolved yet", never "no farm" — tearing the
    // subtree down for it would blank the UI mid-load.
    if (id == null || id == _farmId) return;
    final isFirstResolution = _farmId == null;
    _farmId = id;
    if (isFirstResolution) return;
    setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FarmBloc, FarmState>(
      listener: _onFarmState,
      child: KeyedSubtree(
        key: ValueKey<int>(_generation),
        child: MultiBlocProvider(
          providers: widget.providers,
          child: widget.child,
        ),
      ),
    );
  }
}
