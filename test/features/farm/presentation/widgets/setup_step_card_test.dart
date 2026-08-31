import 'package:farm_tracker/core/widgets/lively_tap.dart';
import 'package:farm_tracker/features/farm/presentation/widgets/setup_step_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an available step is wrapped in an enabled LivelyTap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SetupStepCard(
            stepNumber: 1,
            title: 'Register a herd',
            subtitle: 'Add your first herd',
          ),
        ),
      ),
    );

    expect(find.byType(LivelyTap), findsOneWidget);
    expect(tester.widget<LivelyTap>(find.byType(LivelyTap)).enabled, isTrue);
  });

  testWidgets('a locked step is wrapped in a disabled LivelyTap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SetupStepCard(
            stepNumber: 2,
            title: 'Register a season',
            subtitle: 'Locked until a herd exists',
            status: StepStatus.locked,
          ),
        ),
      ),
    );

    expect(find.byType(LivelyTap), findsOneWidget);
    expect(tester.widget<LivelyTap>(find.byType(LivelyTap)).enabled, isFalse);
  });
}
