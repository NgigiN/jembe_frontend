import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Builds a router that starts at [initialLocation].
typedef RouterFactory = GoRouter Function(String initialLocation);

/// The farm generation, published so `FarmScopedBlocs` can rebuild its
/// providers in the same frame the router is replaced.
class FarmGeneration extends InheritedWidget {
  const FarmGeneration({
    required this.generation,
    required super.child,
    super.key,
  });

  final int generation;

  static int of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FarmGeneration>()
          ?.generation ??
      0;

  @override
  bool updateShouldNotify(FarmGeneration oldWidget) =>
      oldWidget.generation != generation;
}

/// Owns the [GoRouter] and replaces it whenever the current farm changes.
///
/// ## Why the router, and not a key
///
/// Re-keying a subtree that merely contains the Router does nothing. go_router
/// gives its Navigator a `GlobalObjectKey(navigatorKey.hashCode)`, and Flutter
/// REPARENTS a GlobalKey element rather than recreating it. The old Navigator
/// is handed straight back to the new tree, carrying every page `State` with
/// it, so `initState` never runs again and nothing refetches. Hoisting the key
/// higher only moves the problem up a level, because the key is derived from
/// the `GoRouter` instance and that instance has not changed.
///
/// The only thing that breaks the reparenting is a different `navigatorKey`,
/// which means a different `GoRouter`. So that is what a switch does: build a
/// new router seeded with the location the user is on, hand it to the same
/// `MaterialApp`, and dispose the old one.
///
/// This was found the hard way. Switching farm A to B and back left the Plants
/// page on the empty-farm state while the header already read the new farm;
/// `/dashboard` was never re-requested because the page never remounted.
///
/// ## Why MaterialApp is NOT rebuilt
///
/// `Router.didUpdateWidget` handles a changed `routerDelegate` by moving its
/// listener across, so the router can be swapped under a live [MaterialApp].
/// Keeping that [MaterialApp] alive keeps its `ScaffoldMessenger` alive, and
/// with it the "Switched to ..." confirmation the switcher shows immediately
/// after dispatching the change. Rebuilding the app would have thrown that
/// snackbar away silently, which is the one piece of feedback the whole
/// feature exists to give.
///
/// ## Placement
///
/// [FarmBloc] MUST be provided above this widget. It is the thing being
/// listened to, and it has to outlive a switch.
class FarmScopedRouterHost extends StatefulWidget {
  const FarmScopedRouterHost({
    required this.createRouter,
    required this.builder,
    required this.initialLocation,
    super.key,
  });

  /// Builds a fresh router. Called once per farm generation.
  final RouterFactory createRouter;

  /// Builds the app around the current router.
  final Widget Function(BuildContext context, GoRouter router) builder;

  /// Where the very first router starts, before any farm is known.
  final String initialLocation;

  @override
  State<FarmScopedRouterHost> createState() => _FarmScopedRouterHostState();
}

class _FarmScopedRouterHostState extends State<FarmScopedRouterHost> {
  late GoRouter _router = widget.createRouter(widget.initialLocation);

  /// The farm the mounted tree belongs to. Null until the first [FarmLoaded].
  int? _farmId;

  /// Bumped only by a genuine switch.
  ///
  /// Deliberately NOT derived from [_farmId]. On a cold start the first
  /// [FarmLoaded] lands a frame or two after the tree is built, so keying on
  /// the id directly would flip `null` to `7` and rebuild everything that had
  /// just mounted — a doubled fetch of every entity on every launch, to end up
  /// on the farm the app was already showing. Adopting the first id silently
  /// avoids that while still rebuilding on a real switch.
  int _generation = 0;

  static int? _currentFarmId(FarmState state) =>
      state is FarmLoaded ? state.currentFarmId : null;

  /// Where the user is right now, so the replacement router can put them back.
  ///
  /// Read from the match list rather than `GoRouter.state`, which derives from
  /// `currentConfiguration.last` and would throw on an empty stack.
  String _currentLocation() {
    try {
      return _router.routerDelegate.currentConfiguration.uri.toString();
    } catch (_) {
      return widget.initialLocation;
    }
  }

  void _onFarmState(BuildContext context, FarmState state) {
    final id = _currentFarmId(state);
    // A null id means "not resolved yet", never "no farm" — rebuilding for it
    // would blank the UI mid-load.
    if (id == null || id == _farmId) return;
    final isFirstResolution = _farmId == null;
    _farmId = id;
    if (isFirstResolution) return;

    final previous = _router;
    setState(() {
      _router = widget.createRouter(_currentLocation());
      _generation++;
    });
    // Disposing now would tear down a delegate the old tree is still mounted
    // against this frame. Let the frame finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FarmBloc, FarmState>(
      listener: _onFarmState,
      child: FarmGeneration(
        generation: _generation,
        child: widget.builder(context, _router),
      ),
    );
  }
}
