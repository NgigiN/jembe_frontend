import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens in-memory, round-trips a Lands row', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.lands)
        .insert(
          LandsCompanion.insert(
            clientUuid: 'cu-1',
            userId: 'u1',
            name: 'North',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
    final rows = await db.select(db.lands).get();
    expect(rows.single.clientUuid, 'cu-1');
    expect(rows.single.serverId, isNull);
    await db.close();
  });

  test(
    'wipeAll() clears every offline-first table (Lands, Outbox, '
    'SyncCursor) in one go',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      // Seed a row in each of the three tables `wipeAll` targets.
      await db
          .into(db.lands)
          .insert(
            LandsCompanion.insert(
              clientUuid: 'cu-1',
              userId: 'u1',
              name: 'North',
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          );
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              entity: 'land',
              op: 'create',
              clientUuid: 'cu-1',
              updatedAt: DateTime(2026),
            ),
          );
      await db
          .into(db.syncCursor)
          .insert(
            SyncCursorCompanion.insert(
              entity: 'land',
              lastPulledAt: Value(DateTime(2026)),
            ),
          );

      // Sanity check: every table actually has a row before wiping.
      expect(await db.select(db.lands).get(), hasLength(1));
      expect(await db.select(db.outbox).get(), hasLength(1));
      expect(await db.select(db.syncCursor).get(), hasLength(1));

      await db.wipeAll();

      expect(await db.select(db.lands).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await db.select(db.syncCursor).get(), isEmpty);

      await db.close();
    },
  );
}
