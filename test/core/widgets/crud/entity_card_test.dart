import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/lively_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title, subtitle, icon; is wrapped in LivelyTap; calls onTap', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityCard(
            icon: Icons.pets,
            iconColor: Colors.orange,
            title: 'Dairy Herd A',
            subtitle: '12 animals',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Dairy Herd A'), findsOneWidget);
    expect(find.text('12 animals'), findsOneWidget);
    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.byType(LivelyTap), findsOneWidget);

    await tester.tap(find.byType(EntityCard));
    expect(tapped, isTrue);
  });
}
