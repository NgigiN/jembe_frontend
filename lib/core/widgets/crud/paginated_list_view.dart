import 'package:flutter/material.dart';

/// Distance (in logical pixels) from the bottom of the scroll extent at which
/// [PaginatedListView] asks its owner for the next page. ~300px gives the
/// fetch a head start so the next page is usually in place before the user
/// hits the very end.
const double kPaginatedListEndReachedThreshold = 300;

/// A [ListView.builder] that drives cursor-based "infinite scroll" for the
/// ONLINE list path (audit P3-02a).
///
/// It fires [onEndReached] as the viewport nears the bottom (within
/// [kPaginatedListEndReachedThreshold]) while more items can still load, and
/// renders a trailing progress row until [hasReachedMax] is `true`.
///
/// ## Behaviour-neutral for the common case
/// When [hasReachedMax] is already `true` on first build — an account whose
/// entire list fit in the first page (≤ the backend's 500-row cap), or the
/// offline path, which shows the whole local mirror at once — this renders
/// EXACTLY like the plain `ListView.builder` it replaced: no footer row, and
/// [onEndReached] never fires.
///
/// ## Debounce
/// The widget owns (and disposes) its own [ScrollController]. [onEndReached]
/// is latched so a single crossing of the threshold fires it at most once; it
/// re-arms only after the viewport leaves the threshold — which happens
/// naturally once an appended page grows the scroll extent and the user
/// scrolls on toward the new bottom.
class PaginatedListView extends StatefulWidget {
  const PaginatedListView({
    required this.itemCount,
    required this.itemBuilder,
    required this.hasReachedMax,
    required this.onEndReached,
    this.padding,
    this.physics,
    super.key,
  });

  /// Number of real (data) items — the trailing loader row, when shown, is
  /// added on top of this and is NOT counted here.
  final int itemCount;

  /// Builds a real item for `index` in `[0, itemCount)`. Same signature as
  /// `ListView.builder`'s `itemBuilder`, so it drops in unchanged.
  final IndexedWidgetBuilder itemBuilder;

  /// When `true`, no more pages exist: the footer is hidden and
  /// [onEndReached] never fires. The offline path and any ≤500-row account
  /// pass `true` here from first build.
  final bool hasReachedMax;

  /// Called once when the viewport nears the bottom and more can still load.
  final VoidCallback onEndReached;

  /// Pass-through to [ListView.builder.padding] — matches the existing
  /// `context.scrollListPadding(...)` usage at each call site.
  final EdgeInsetsGeometry? padding;

  /// Pass-through to [ListView.builder.physics] — call sites use
  /// `AlwaysScrollableScrollPhysics` so a short list still accepts the
  /// pull-to-refresh gesture.
  final ScrollPhysics? physics;

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  final ScrollController _controller = ScrollController();

  /// Debounce latch: `true` while the viewport is inside the bottom threshold
  /// AND [PaginatedListView.onEndReached] has already fired for this crossing.
  /// Reset once the viewport leaves the threshold, so each fresh approach
  /// fires exactly once.
  bool _endReachedFired = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final atThreshold = position.pixels >=
        position.maxScrollExtent - kPaginatedListEndReachedThreshold;
    if (!atThreshold) {
      // Re-arm: the user has scrolled back out of the threshold (or an
      // appended page grew the extent beneath them).
      _endReachedFired = false;
      return;
    }
    if (widget.hasReachedMax || _endReachedFired) return;
    _endReachedFired = true;
    widget.onEndReached();
  }

  @override
  Widget build(BuildContext context) {
    // One extra row for the trailing loader while more can still load.
    final showFooter = !widget.hasReachedMax;
    final rowCount = widget.itemCount + (showFooter ? 1 : 0);

    return ListView.builder(
      controller: _controller,
      physics: widget.physics,
      padding: widget.padding,
      itemCount: rowCount,
      itemBuilder: (context, index) {
        if (index >= widget.itemCount) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return widget.itemBuilder(context, index);
      },
    );
  }
}
