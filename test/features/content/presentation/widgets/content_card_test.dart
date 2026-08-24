import 'package:farm_tracker/features/content/domain/entities/content_item.dart';
import 'package:farm_tracker/features/content/presentation/widgets/content_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title and source-attributed summary, and calls onTap', (
    tester,
  ) async {
    var tapped = false;
    final item = ContentItem(
      id: 'a',
      title: 'Preventing mastitis',
      summary: 'Three habits that help.',
      body: 'body',
      language: 'en',
      source: 'KALRO',
      animalTypeTags: const ['dairy cattle'],
      cropTags: const [],
      publishedAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentCard(item: item, onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Preventing mastitis'), findsOneWidget);
    expect(find.text('Three habits that help.'), findsOneWidget);

    await tester.tap(find.byType(ContentCard));
    expect(tapped, isTrue);
  });
}
