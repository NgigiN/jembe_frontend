import 'package:farm_tracker/core/farm_scope/farm_scoped_router_host.dart';
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
/// wrote the new id to storage and emitted `FarmLoaded`, and all sixteen
/// blocs carried on serving the previous farm's rows.
///
/// Rebuilding them costs no per-bloc code and covers blocs that do not exist
/// yet: every farm-scoped bloc is a `registerFactory`, so each resolve is a
/// new object. Scoping is a per-request `X-Farm-ID` header, so the refetch
/// lands on the right farm with no further plumbing.
///
/// ## This widget does not own the rebuild
/// It reads the generation published by [FarmScopedRouterHost] and keys its
/// providers on it, so fresh blocs appear in the same frame as the new router.
///
/// That split matters, and an earlier version of this file got it wrong. It
/// claimed that re-keying here "rebuilds the page without losing the user's
/// place", reasoning that go_router keeps its route stack in the `GoRouter`
/// rather than the widget tree. The stack does live there — but the Navigator
/// ELEMENT carries a `GlobalObjectKey`, and Flutter reparents a GlobalKey
/// element instead of recreating it. So the pages rode across every rebuild,
/// `initState` never re-ran, and a switch swapped the blocs under pages that
/// never refetched. Replacing the router is what actually remounts them; see
/// [FarmScopedRouterHost].
///
/// ## Placement
/// Goes in `MaterialApp.router`'s `builder:`, below the host and above the
/// Navigator, so pushed routes are covered too.
///
/// Identity-scoped blocs (Auth, Farm, Theme, Profile, ...) MUST be provided
/// ABOVE the host. They outlive a switch.
///
/// ## Cost
/// The rebuild discards transient page state: scroll offsets, and a
/// half-filled form on a pushed route. That is intended — that state refers
/// to the farm the user just left.
class FarmScopedBlocs extends StatelessWidget {
  const FarmScopedBlocs({
    required this.providers,
    required this.child,
    super.key,
  });

  /// The farm-scoped providers. Rebuilt wholesale on every switch.
  final List<SingleChildWidget> providers;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(FarmGeneration.of(context)),
      child: MultiBlocProvider(providers: providers, child: child),
    );
  }
}
