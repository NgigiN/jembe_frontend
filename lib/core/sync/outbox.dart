import 'package:drift/drift.dart' hide coalesce;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/outbox_coalescing.dart';

/// Drift-backed FIFO outbox queue.
///
/// [enqueue] applies the Task 2 coalescing rules (see
/// `outbox_coalescing.dart`) transactionally: a new intent is merged against
/// whatever's still `pending` for the same `clientUuid`, and the result
/// replaces those rows in the database. Everything else (`peekAll`, `ack`,
/// `markFailed`, `pendingCount`) is a thin, non-coalescing read/write over
/// the `Outbox` table.
class OutboxDao {
  OutboxDao(this._db);

  final AppDatabase _db;

  /// Enqueues [intent], coalescing it against the same-`clientUuid`
  /// `pending` rows already in the outbox.
  ///
  /// Runs inside a single `db.transaction` so a concurrent enqueue can never
  /// observe (or write) a partial rewrite: the same-`clientUuid` pending
  /// rows are read, [coalesce]d with [intent], then the old rows are
  /// deleted and the coalesced set is re-inserted, all atomically.
  ///
  /// The survivors of a coalesce are re-inserted, so they get fresh `seq`
  /// values — this reorders them relative to their original position, but
  /// only *within this one `clientUuid`*. Rows for every other `clientUuid`
  /// are untouched, so FIFO order across different `clientUuid`s is
  /// preserved; the per-`clientUuid` reordering is harmless because at most
  /// one not-yet-synced entry ever exists per `clientUuid` at a time.
  Future<void> enqueue(OutboxIntent intent) async {
    await _db.transaction(() async {
      final existingRows =
          await (_db.select(_db.outbox)..where(
                (row) =>
                    row.clientUuid.equals(intent.clientUuid) &
                    row.state.equals('pending'),
              ))
              .get();

      final coalesced = coalesce(existingRows.map(_toIntent).toList(), intent);

      if (existingRows.isNotEmpty) {
        await (_db.delete(
              _db.outbox,
            )..where((row) => row.seq.isIn(existingRows.map((row) => row.seq))))
            .go();
      }

      final now = DateTime.now();
      for (final coalescedIntent in coalesced) {
        await _db
            .into(_db.outbox)
            .insert(
              OutboxCompanion.insert(
                entity: coalescedIntent.entity,
                op: coalescedIntent.op.name,
                clientUuid: coalescedIntent.clientUuid,
                payload: Value(coalescedIntent.payload),
                updatedAt: now,
              ),
            );
      }
    });
  }

  /// All outbox rows, any state, ordered by `seq` ascending (FIFO).
  Future<List<OutboxRow>> peekAll() {
    return (_db.select(
      _db.outbox,
    )..orderBy([(row) => OrderingTerm.asc(row.seq)])).get();
  }

  /// Removes the row at [seq] — call once it's been synced successfully.
  Future<void> ack(int seq) async {
    await (_db.delete(_db.outbox)..where((row) => row.seq.equals(seq))).go();
  }

  /// Marks the row at [seq] as `failed` and increments its attempt count.
  Future<void> markFailed(int seq) async {
    final row = await (_db.select(
      _db.outbox,
    )..where((r) => r.seq.equals(seq))).getSingle();

    await (_db.update(_db.outbox)..where((r) => r.seq.equals(seq))).write(
      OutboxCompanion(
        state: const Value('failed'),
        attempts: Value(row.attempts + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// The number of rows still awaiting sync (`state == 'pending'`).
  Future<int> pendingCount() async {
    final query = _db.selectOnly(_db.outbox)
      ..where(_db.outbox.state.equals('pending'))
      ..addColumns([_db.outbox.seq.count()]);
    final row = await query.getSingle();
    return row.read(_db.outbox.seq.count()) ?? 0;
  }

  OutboxIntent _toIntent(OutboxRow row) {
    return OutboxIntent(
      op: OutboxOp.values.byName(row.op),
      clientUuid: row.clientUuid,
      entity: row.entity,
      payload: row.payload,
    );
  }
}
