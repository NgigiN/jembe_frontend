class FeedEntry {
  const FeedEntry({
    required this.entityType,
    required this.summary,
    required this.loggedByUserId,
    required this.loggedByFirstName,
    required this.loggedByLastName,
    required this.createdAt,
    this.detail,
    this.amount,
  });

  final String entityType;
  final String summary;

  /// The short qualifier beside the summary — an activity's own note, a
  /// harvest's quantity and unit. Null where the entry has none.
  final String? detail;

  /// Signed KES: negative for what the farm spent, positive for what it
  /// took in. Null where the entry is not about money, which is why this
  /// is nullable rather than defaulting to zero — a zero amount and no
  /// amount read differently in a column of figures.
  final double? amount;
  final int? loggedByUserId;
  final String? loggedByFirstName;
  final String? loggedByLastName;
  final DateTime createdAt;
}
