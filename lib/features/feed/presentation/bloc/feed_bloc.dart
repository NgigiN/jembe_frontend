import 'package:farm_tracker/features/feed/data/datasources/feed_remote_data_source.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_event.dart';
import 'package:farm_tracker/features/feed/presentation/bloc/feed_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({required this.remote}) : super(FeedInitial()) {
    on<LoadFeed>((event, emit) async {
      emit(FeedLoading());
      try {
        final page = await remote.getFeed();
        emit(FeedLoaded(entries: page.entries, hasMore: page.nextBefore != null, nextBefore: page.nextBefore));
      } on Object catch (_) {
        emit(FeedError('Unable to load the feed.'));
      }
    });

    on<LoadMoreFeed>((event, emit) async {
      final current = state;
      if (current is! FeedLoaded || !current.hasMore || _loadingMore) return;
      _loadingMore = true;
      try {
        final page = await remote.getFeed(before: current.nextBefore);
        emit(FeedLoaded(
          entries: [...current.entries, ...page.entries],
          hasMore: page.nextBefore != null,
          nextBefore: page.nextBefore,
        ));
      } on Object catch (_) {
        // Keep the existing loaded page on a "load more" failure — a
        // partial feed is still useful; don't blank it out.
      } finally {
        _loadingMore = false;
      }
    });
  }

  final FeedRemoteDataSource remote;

  /// Guards against `FeedPage`'s `ListView.builder` re-dispatching
  /// `LoadMoreFeed` on a rebuild while the previous fetch for the same page
  /// is still in flight (Flutter can re-invoke `itemBuilder` for an already-
  /// visible index on scroll/resize, not just once) — without this, bloc's
  /// default concurrent event transformer would run both fetches in
  /// parallel against the same cursor, risking a duplicate request or an
  /// out-of-order response overwriting newer state.
  bool _loadingMore = false;
}
