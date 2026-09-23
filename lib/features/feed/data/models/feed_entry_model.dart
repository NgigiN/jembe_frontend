import 'package:farm_tracker/features/feed/domain/entities/feed_entry.dart';

class FeedEntryModel extends FeedEntry {
  const FeedEntryModel({
    required super.entityType,
    required super.summary,
    required super.loggedByUserId,
    required super.loggedByFirstName,
    required super.loggedByLastName,
    required super.createdAt,
    super.detail,
    super.amount,
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
      // Both arrived with the feed's amount/detail change; tolerated as
      // absent so a console build can run against a server that predates
      // it rather than throwing on every row.
      detail: _nonEmpty(json['detail']),
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }

  /// The server sends "" for an entry with no detail; the console wants
  /// null so it can render the spec's em dash.
  static String? _nonEmpty(Object? value) {
    final text = value as String?;
    return text == null || text.isEmpty ? null : text;
  }
}
