import 'package:drift/drift.dart';
import 'package:farm_tracker/core/database/app_database.dart';

/// Reads and writes the per-entity pull cursor (`SyncCursor` table).
///
/// The cursor is the greatest `updatedAt` the engine has successfully pulled
/// for an entity; the next pull asks the server for changes strictly after
/// it. Values round-trip through drift as local-zone [DateTime]s, so callers
/// MUST compare them with `isAfter`/`isBefore`/`isAtSameMomentAs`, never `==`.
class SyncCursorDao {
  SyncCursorDao(this._db);

  final AppDatabase _db;

  /// The stored cursor for [entity], or null if it was never set.
  Future<DateTime?> get(String entity) async {
    final row =
        await (_db.select(_db.syncCursor)
              ..where((r) => r.entity.equals(entity)))
            .getSingleOrNull();
    return row?.lastPulledAt;
  }

  /// Upserts the cursor for [entity] to [at].
  Future<void> set(String entity, DateTime at) async {
    await _db
        .into(_db.syncCursor)
        .insertOnConflictUpdate(
          SyncCursorCompanion.insert(entity: entity, lastPulledAt: Value(at)),
        );
  }
}
