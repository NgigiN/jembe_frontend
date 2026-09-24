import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';

abstract class FeedState {}
class FeedInitial extends FeedState {}
class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  FeedLoaded({required this.entries, required this.hasMore, this.nextBefore});
  final List<FeedEntry> entries;
  final bool hasMore;
  final String? nextBefore;
}

class FeedError extends FeedState {
  FeedError(this.message);
  final String message;
}
