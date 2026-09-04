import 'dart:async';

import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Opens an [EntityFormSheet] with a single text field and a 'Save' submit
  /// button, wired to [onSubmit]. Leaves the sheet fully settled and open.
  Future<void> showSheet(
    WidgetTester tester, {
    required Future<bool> Function(BuildContext sheetContext) onSubmit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => EntityFormSheet.show(
                context: context,
                title: 'Test Form',
                submitLabel: 'Save',
                fields: const [TextField()],
                onSubmit: onSubmit,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'stays open and re-enables when onSubmit returns false',
    (tester) async {
      final completer = Completer<bool>();
      await showSheet(tester, onSubmit: (_) => completer.future);

      await tester.tap(find.text('Save'));
      await tester.pump(); // spinner shown while awaiting
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(false);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets); // sheet still open
    },
  );

  testWidgets('pops when onSubmit returns true', (tester) async {
    await showSheet(tester, onSubmit: (_) async => true);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing); // sheet closed
  });

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
