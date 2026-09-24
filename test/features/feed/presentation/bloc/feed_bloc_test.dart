// test/features/feed/presentation/bloc/feed_bloc_test.dart
import 'dart:async';

import 'package:farm_tracker/features/feed/data/datasources/feed_remote_data_source.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements FeedRemoteDataSource {}

FeedEntry _entry(String type) => FeedEntry(
  entityType: type, summary: type, loggedByUserId: 1,
  loggedByFirstName: 'A', loggedByLastName: 'B', createdAt: DateTime(2026, 9, 22),
);

void main() {
  late _MockRemote remote;
  setUp(() => remote = _MockRemote());

  test('LoadFeed emits FeedLoaded with the first page', () async {
    when(() => remote.getFeed()).thenAnswer(
      (_) async => FeedPage(entries: [_entry('activity')], nextBefore: 'cursor-1'),
    );
    final bloc = FeedBloc(remote: remote);
    addTearDown(bloc.close);

    bloc.add(LoadFeed());
    final state = await bloc.stream.firstWhere((s) => s is FeedLoaded);

    expect((state as FeedLoaded).entries, hasLength(1));
    expect(state.hasMore, isTrue);
  });

  test('LoadMoreFeed appends to existing entries using the stored cursor', () async {
    when(() => remote.getFeed()).thenAnswer(
      (_) async => FeedPage(entries: [_entry('activity')], nextBefore: 'cursor-1'),
    );
    when(() => remote.getFeed(before: 'cursor-1')).thenAnswer(
      (_) async => FeedPage(entries: [_entry('harvest')], nextBefore: null),
    );
    final bloc = FeedBloc(remote: remote);
    addTearDown(bloc.close);

    bloc.add(LoadFeed());
    await bloc.stream.firstWhere((s) => s is FeedLoaded);

    bloc.add(LoadMoreFeed());
    final state = await bloc.stream.firstWhere((s) => s is FeedLoaded && s.entries.length == 2);

    expect((state as FeedLoaded).entries.map((e) => e.entityType), ['activity', 'harvest']);
    expect(state.hasMore, isFalse);
    verify(() => remote.getFeed(before: 'cursor-1')).called(1);
  });

  test('LoadFeed emits FeedError on failure', () async {
    when(() => remote.getFeed()).thenThrow(Exception('boom'));
    final bloc = FeedBloc(remote: remote);
    addTearDown(bloc.close);

    bloc.add(LoadFeed());
    final state = await bloc.stream.firstWhere((s) => s is FeedError);

    expect(state, isA<FeedError>());
  });

  test(
    'LoadMoreFeed ignores a duplicate dispatch while a fetch is already in flight',
    () async {
      when(() => remote.getFeed()).thenAnswer(
        (_) async => FeedPage(entries: [_entry('activity')], nextBefore: 'cursor-1'),
      );
      final completer = Completer<FeedPage>();
      when(() => remote.getFeed(before: 'cursor-1'))
          .thenAnswer((_) => completer.future);

      final bloc = FeedBloc(remote: remote);
      addTearDown(bloc.close);

      bloc.add(LoadFeed());
      await bloc.stream.firstWhere((s) => s is FeedLoaded);

      // Fire twice before the in-flight fetch resolves — simulates itemBuilder
      // re-firing LoadMoreFeed on a second rebuild while the first is still pending.
      bloc.add(LoadMoreFeed());
      bloc.add(LoadMoreFeed());
      await Future<void>.delayed(Duration.zero);

      completer.complete(FeedPage(entries: [_entry('harvest')], nextBefore: null));
      final state = await bloc.stream.firstWhere(
        (s) => s is FeedLoaded && s.entries.length == 2,
      );

      expect(
        (state as FeedLoaded).entries.map((e) => e.entityType),
        ['activity', 'harvest'],
      );
      // The duplicate dispatch must not have reached the data source a second time.
      verify(() => remote.getFeed(before: 'cursor-1')).called(1);
    },
  );
}
