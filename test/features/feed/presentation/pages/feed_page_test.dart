import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_state.dart';
import 'package:farm_tracker/features/feed/presentation/pages/feed_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFeedBloc extends MockBloc<FeedEvent, FeedState> implements FeedBloc {}

void main() {
  setUpAll(() => registerFallbackValue(LoadFeed()));

  testWidgets('renders entries with logged_by name', (tester) async {
    final bloc = MockFeedBloc();
    final entry = FeedEntry(
      entityType: 'activity', summary: 'Activity: watering',
      loggedByUserId: 1, loggedByFirstName: 'Amina', loggedByLastName: 'Kamau',
      createdAt: DateTime(2026, 9, 22, 10),
    );
    whenListen(bloc, const Stream<FeedState>.empty(), initialState: FeedLoaded(entries: [entry], hasMore: false));

    await tester.pumpWidget(
      BlocProvider<FeedBloc>.value(value: bloc, child: const MaterialApp(home: FeedPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity: watering'), findsOneWidget);
    expect(find.text('Amina Kamau'), findsOneWidget);
  });

  testWidgets('dispatches LoadFeed on init', (tester) async {
    final bloc = MockFeedBloc();
    whenListen(bloc, const Stream<FeedState>.empty(), initialState: FeedInitial());

    await tester.pumpWidget(
      BlocProvider<FeedBloc>.value(value: bloc, child: const MaterialApp(home: FeedPage())),
    );
    await tester.pump();

    verify(() => bloc.add(any(that: isA<LoadFeed>()))).called(1);
  });
}
