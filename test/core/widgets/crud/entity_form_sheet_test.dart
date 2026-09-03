import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpContainer(
    WidgetTester tester, {
    required Size size,
    required EdgeInsets viewInsets,
    EdgeInsets padding = EdgeInsets.zero,
    double heightFactor = 0.8,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: viewInsets.bottom);
    tester.view.padding = FakeViewPadding(bottom: padding.bottom);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // A bare `home:` gets tight constraints that would force the sheet
        // to fill the screen regardless of its requested height. Align
        // (matching how showModalBottomSheet actually lays out its
        // builder content) gives it loose constraints instead, so it can
        // size itself.
        home: Align(
          alignment: Alignment.bottomCenter,
          child: Builder(
            builder: (context) => EntityFormSheet.container(
              context: context,
              heightFactor: heightFactor,
              child: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'keeps its normal heightFactor height when the keyboard opens but the '
    'sheet still fits in the remaining space',
    (tester) async {
      const size = Size(400, 800);

      await pumpContainer(tester, size: size, viewInsets: EdgeInsets.zero);
      final noKeyboardHeight =
          tester.getSize(find.byType(AnimatedContainer)).height;

      await pumpContainer(
        tester,
        size: size,
        viewInsets: const EdgeInsets.only(bottom: 100),
      );
      final withKeyboardHeight =
          tester.getSize(find.byType(AnimatedContainer)).height;

      expect(withKeyboardHeight, noKeyboardHeight);
    },
  );

  testWidgets(
    'shrinks only enough to avoid overflowing above the screen when the '
    'keyboard is taller than the remaining headroom',
    (tester) async {
      // heightFactor 0.8 on an 800-tall screen wants a 640 sheet, but a
      // 300px keyboard leaves only 500px of vertical space above it.
      await pumpContainer(
        tester,
        size: const Size(400, 800),
        viewInsets: const EdgeInsets.only(bottom: 300),
      );

      final height = tester.getSize(find.byType(AnimatedContainer)).height;

      expect(height, 500);
    },
  );
}
