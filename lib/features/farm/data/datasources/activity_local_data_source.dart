import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';

/// Drift-backed local data source for the activity feature.
///
/// Gives the activity feature reactive local reads ([watchActivities]) and
/// local writes ([upsert], [markDeleted], [hardDelete], [setServerId]) over
/// the `Activities` table, so the rest of the offline-first pipeline
/// (outbox/pull) can stage mutations before — and independently of —
/// syncing with the server. Every method keys rows by `clientUuid` (the
/// table's primary key), never by [ActivityModel] value-equality (which
/// deliberately excludes `clientUuid` — see `ActivityModel`'s
/// `Equatable.props`).
///
/// Satisfies [LocalSyncStore] so `BaseEntitySyncer<ActivityModel>` can drive
/// the local mirror through the generic contract; the extra reactive-read
/// ([watchActivities]) and [clear] methods are activity-specific and sit
/// outside that interface.
class ActivityLocalDataSource implements LocalSyncStore<ActivityModel> {
  ActivityLocalDataSource(this._db);

  final AppDatabase _db;

  /// Reactive stream of activities, excluding local tombstones
  /// (`deletedLocally == true`), optionally filtered to a single
  /// [sourceType] — mirrors `activity_page.dart`'s existing
  /// `GetActivitiesEvent(sourceType:)` scoped list. `sourceType` is a
  /// stable string discriminator ('plant'/'animal'/…), not a parent id, so
  /// this filter has no clientUuid concern (unlike the
  /// `animalId`/`sourceId` FK — see `ActivityModel`'s notes on `.create()`).
  ///
  /// Ordered by `createdAt` ascending (oldest first) — a stable order tied
  /// to when an activity was first created locally, unaffected by later
  /// edits.
  Stream<List<ActivityModel>> watchActivities({String? sourceType}) {
    final query = _db.select(_db.activities)
      ..where((row) => row.deletedLocally.equals(false));
    if (sourceType != null && sourceType.isNotEmpty) {
      query.where((row) => row.sourceType.equals(sourceType));
    }
    query.orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(ActivityModel.fromDrift).toList(),
    );
  }

  /// Inserts [model], or replaces the existing row sharing its
  /// `clientUuid` (the primary key) if one already exists.
  @override
  Future<void> upsert(ActivityModel model, {required bool pending}) {
    return _db
        .into(_db.activities)
        .insertOnConflictUpdate(model.toCompanion(pending: pending));
  }

  /// Marks the row for [clientUuid] as a tombstone awaiting delete-sync:
  /// `deletedLocally = true`, `pending = true`. The row is not removed —
  /// call [hardDelete] once the delete has synced with the server.
  @override
  Future<void> markDeleted(String clientUuid) {
    return (_db.update(
      _db.activities,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      const ActivitiesCompanion(
        deletedLocally: Value(true),
        pending: Value(true),
      ),
    );
  }

  /// Physically removes the row for [clientUuid] — call once a delete has
  /// synced with the server.
  @override
  Future<void> hardDelete(String clientUuid) {
    return (_db.delete(
      _db.activities,
    )..where((row) => row.clientUuid.equals(clientUuid))).go();
  }

  /// Reconciles the row for [clientUuid] after a create/update syncs: sets
  /// [serverId] and [updatedAt], and clears `pending`.
  @override
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) {
    return (_db.update(
      _db.activities,
    )..where((row) => row.clientUuid.equals(clientUuid))).write(
      ActivitiesCompanion(
        serverId: Value(serverId),
        updatedAt: Value(updatedAt),
        pending: const Value(false),
      ),
    );
  }

  /// The activity with the given [clientUuid], or `null` if no such row
  /// exists. Includes local tombstones (unlike [watchActivities]).
  @override
  Future<ActivityModel?> getByClientUuid(String clientUuid) async {
    final row = await (_db.select(
      _db.activities,
    )..where((r) => r.clientUuid.equals(clientUuid))).getSingleOrNull();
    return row == null ? null : ActivityModel.fromDrift(row);
  }

  /// The activity with the given server [serverId], or `null` if no such
  /// row exists.
  @override
  Future<ActivityModel?> getByServerId(String serverId) async {
    final row = await (_db.select(
      _db.activities,
    )..where((r) => r.serverId.equals(serverId))).getSingleOrNull();
    return row == null ? null : ActivityModel.fromDrift(row);
  }

  /// Deletes every row — used to wipe the local mirror on logout.
  Future<void> clear() => _db.delete(_db.activities).go();
}
