import 'package:farm_tracker/core/widgets/crud/paginated_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Each item is a fixed 100px so item-count × 100 is the content height; the
  // default test viewport is 800×600, so 20 items (2000px) is comfortably
  // scrollable and 3 items (300px) is not.
  Widget buildHarness({
    required int itemCount,
    required bool hasReachedMax,
    required VoidCallback onEndReached,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PaginatedListView(
          itemCount: itemCount,
          hasReachedMax: hasReachedMax,
          onEndReached: onEndReached,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) =>
              SizedBox(height: 100, child: Text('item $index')),
        ),
      ),
    );
  }

  testWidgets(
    'renders no trailing loader and never calls onEndReached when '
    'hasReachedMax is true (≤500-row / offline parity)',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        buildHarness(
          itemCount: 20,
          hasReachedMax: true,
          onEndReached: () => calls++,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(calls, 0);
    },
  );

  testWidgets(
    'renders a trailing loading indicator while more can load '
    '(hasReachedMax false)',
    (tester) async {
      await tester.pumpWidget(
        buildHarness(
          itemCount: 3,
          hasReachedMax: false,
          onEndReached: () {},
        ),
      );
      // 3 short items + footer all fit the viewport, so the footer builds
      // immediately.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'fires onEndReached once when scrolled near the bottom, and does not '
    're-fire while still within the threshold (debounce)',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        buildHarness(
          itemCount: 20,
          hasReachedMax: false,
          onEndReached: () => calls++,
        ),
      );

      // At rest at the top, nowhere near the bottom → not yet fired.
      expect(calls, 0);

      // Not pumpAndSettle: the trailing CircularProgressIndicator animates
      // forever, so a fixed pump advances the scroll without waiting to
      // settle.
      await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);

      // Still pinned at the bottom (inside the threshold): the latch prevents
      // a second fire for the same crossing.
      await tester.drag(find.byType(Scrollable), const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
    },
  );

  testWidgets('disposes its ScrollController without error', (tester) async {
    await tester.pumpWidget(
      buildHarness(itemCount: 20, hasReachedMax: false, onEndReached: () {}),
    );
    // Replacing the widget triggers State.dispose on PaginatedListView.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(tester.takeException(), isNull);
  });
}
