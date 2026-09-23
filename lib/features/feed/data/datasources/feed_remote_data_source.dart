import 'package:dio/dio.dart';
import 'package:farm_tracker/features/feed/data/models/feed_entry_model.dart';
import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';

class FeedPage {
  const FeedPage({required this.entries, required this.nextBefore});
  final List<FeedEntry> entries;
  final String? nextBefore;
}

abstract class FeedRemoteDataSource {
  Future<FeedPage> getFeed({String? before, int limit = 20});
}

class FeedRemoteDataSourceImpl implements FeedRemoteDataSource {
  FeedRemoteDataSourceImpl({required this.dio});
  final Dio dio;

  @override
  Future<FeedPage> getFeed({String? before, int limit = 20}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/farms/current/feed',
      queryParameters: {
        'limit': limit,
        if (before != null) 'before': before,
      },
    );
    final data = response.data!;
    final entries = (data['entries'] as List<dynamic>)
        .map((e) => FeedEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return FeedPage(entries: entries, nextBefore: data['next_before'] as String?);
  }
}
