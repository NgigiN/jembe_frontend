import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';

class FeedEntryModel extends FeedEntry {
  const FeedEntryModel({
    required super.entityType,
    required super.summary,
    required super.loggedByUserId,
    required super.loggedByFirstName,
    required super.loggedByLastName,
    required super.createdAt,
  });

  factory FeedEntryModel.fromJson(Map<String, dynamic> json) {
    final loggedBy = json['logged_by'] as Map<String, dynamic>?;
    return FeedEntryModel(
      entityType: json['entity_type'] as String,
      summary: json['summary'] as String,
      loggedByUserId: loggedBy?['user_id'] as int?,
      loggedByFirstName: loggedBy?['first_name'] as String?,
      loggedByLastName: loggedBy?['last_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
