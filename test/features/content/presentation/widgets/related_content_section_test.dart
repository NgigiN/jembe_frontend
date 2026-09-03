import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/content/domain/entities/content_item.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/content/presentation/widgets/related_content_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockContentBloc extends MockBloc<ContentEvent, ContentState>
    implements ContentBloc {}

ContentItem _dairyItem() => ContentItem(
  id: 'a',
  title: 'Preventing mastitis',
  summary: 'summary',
  body: 'body',
  language: 'en',
  source: 'KALRO',
  animalTypeTags: const ['dairy cattle'],
  cropTags: const [],
  publishedAt: DateTime(2026, 8),
);

void main() {
  testWidgets('renders nothing when there is no matching content', (
    tester,
  ) async {
    final bloc = MockContentBloc();
    whenListen(
      bloc,
      Stream<ContentState>.value(ContentLoaded(items: [_dairyItem()])),
      initialState: ContentLoaded(items: [_dairyItem()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ContentBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: RelatedContentSection(
              matchNames: ['goats'],
              kind: ContentMatchKind.animal,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tips for you'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // SizedBox.shrink()
  });

  testWidgets('renders matching content under a "Tips for you" header', (
    tester,
  ) async {
    final bloc = MockContentBloc();
    whenListen(
      bloc,
      Stream<ContentState>.value(ContentLoaded(items: [_dairyItem()])),
      initialState: ContentLoaded(items: [_dairyItem()]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ContentBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: RelatedContentSection(
              matchNames: ['Dairy Cattle'],
              kind: ContentMatchKind.animal,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tips for you'), findsOneWidget);
    expect(find.text('Preventing mastitis'), findsOneWidget);
  });
}
