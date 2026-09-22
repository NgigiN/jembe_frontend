class FeedEntry {
  const FeedEntry({
    required this.entityType,
    required this.summary,
    required this.loggedByUserId,
    required this.loggedByFirstName,
    required this.loggedByLastName,
    required this.createdAt,
  });

  final String entityType;
  final String summary;
  final int? loggedByUserId;
  final String? loggedByFirstName;
  final String? loggedByLastName;
  final DateTime createdAt;
}
