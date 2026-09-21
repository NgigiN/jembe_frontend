import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Guards the profile Theme selector against label wrapping. Reproduces the
// icon+label SegmentedButton at a narrow width with a larger font scale and
// detects wrapping by comparing the "System" label height against the
// never-wrapping "Dark" label (a one-line reference).

const _segments = <ButtonSegment<ThemeMode>>[
  ButtonSegment(
    value: ThemeMode.system,
    icon: Icon(Icons.brightness_auto),
    label: Text('System'),
  ),
  ButtonSegment(
    value: ThemeMode.light,
    icon: Icon(Icons.light_mode),
    label: Text('Light'),
  ),
  ButtonSegment(
    value: ThemeMode.dark,
    icon: Icon(Icons.dark_mode),
    label: Text('Dark'),
  ),
];

Widget _harness({required bool withFittedBox}) {
  final button = SegmentedButton<ThemeMode>(
    segments: _segments,
    selected: const {ThemeMode.system},
  );
  return MaterialApp(
    home: Scaffold(
      body: Center(
        // 260px mirrors the cramped profile-card width; the 1.3x text scale
        // mirrors a device with a larger system font — the condition that
        // pushed "System" onto a second line.
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: SizedBox(
            width: 260,
            child: withFittedBox
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: button,
                  )
                : button,
          ),
        ),
      ),
    ),
  );
}

double _labelHeight(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).height;

void main() {
  testWidgets('without the fix, "System" wraps taller than a one-line label',
      (tester) async {
    await tester.pumpWidget(_harness(withFittedBox: false));
    final oneLine = _labelHeight(tester, 'Dark');
    final system = _labelHeight(tester, 'System');
    expect(system, greaterThan(oneLine * 1.2)); // wrapped to a second line
  });

  testWidgets('with FittedBox, "System" stays on a single line',
      (tester) async {
    await tester.pumpWidget(_harness(withFittedBox: true));
    final oneLine = _labelHeight(tester, 'Dark');
    final system = _labelHeight(tester, 'System');
    expect(system, closeTo(oneLine, 0.5)); // single line, no wrap
  });
}
