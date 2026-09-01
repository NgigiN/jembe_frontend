import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const colors = StatusColors(
    positive: Color(0xFF111111),
    warning: Color(0xFF222222),
    negative: Color(0xFF333333),
  );
  const other = StatusColors(
    positive: Color(0xFFAAAAAA),
    warning: Color(0xFFBBBBBB),
    negative: Color(0xFFCCCCCC),
  );

  test('copyWith overrides only the given fields', () {
    final updated = colors.copyWith(negative: const Color(0xFF444444));
    expect(updated.positive, colors.positive);
    expect(updated.warning, colors.warning);
    expect(updated.negative, const Color(0xFF444444));
  });

  test("lerp at t=0 returns this instance's values", () {
    final result = colors.lerp(other, 0);
    expect(result.positive, colors.positive);
    expect(result.warning, colors.warning);
    expect(result.negative, colors.negative);
  });

  test("lerp at t=1 returns the other instance's values", () {
    final result = colors.lerp(other, 1);
    expect(result.positive, other.positive);
    expect(result.warning, other.warning);
    expect(result.negative, other.negative);
  });

  test('lerp with a non-StatusColors other returns this instance unchanged', () {
    final result = colors.lerp(null, 0.5);
    expect(result, colors);
  });

  testWidgets(
    'BuildContext.statusColors resolves the registered extension',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [colors]),
          home: Builder(
            builder: (context) {
              expect(context.statusColors, colors);
              return const SizedBox();
            },
          ),
        ),
      );
    },
  );
}
