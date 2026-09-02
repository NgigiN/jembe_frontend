import 'package:farm_tracker/core/widgets/lively_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Animation<double> currentScale(WidgetTester tester) => tester
      .widget<ScaleTransition>(
        find.descendant(
          of: find.byType(LivelyTap),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale;

  testWidgets('scales down on pointer down and back up on pointer up', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivelyTap(child: SizedBox(width: 100, height: 100)),
        ),
      ),
    );

    expect(currentScale(tester).value, 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LivelyTap)),
    );
    // startGesture() dispatches the pointer event but doesn't pump a frame,
    // so the AnimationController's ticker doesn't establish its start
    // reference until the next pumped frame - this zero-duration pump
    // establishes that baseline before measuring the 100ms that follows.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(currentScale(tester).value, closeTo(0.96, 0.001));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(currentScale(tester).value, 1.0);
  });

  testWidgets('fires a selection-click haptic on pointer down', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivelyTap(child: SizedBox(width: 100, height: 100)),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LivelyTap)),
    );
    await gesture.up();

    final hapticCalls = calls.where(
      (call) => call.method == 'HapticFeedback.vibrate',
    );
    expect(hapticCalls, hasLength(1));
    expect(hapticCalls.single.arguments, 'HapticFeedbackType.selectionClick');
  });

  testWidgets(
    'does not prevent the wrapped child from receiving its own tap',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LivelyTap(
              child: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      expect(tapped, isTrue);
    },
  );

  testWidgets('enabled: false renders the child directly, no scale or haptic', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LivelyTap(
            enabled: false,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(LivelyTap),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox)),
    );
    await gesture.up();
    expect(
      calls.where((call) => call.method == 'HapticFeedback.vibrate'),
      isEmpty,
    );
  });
}
