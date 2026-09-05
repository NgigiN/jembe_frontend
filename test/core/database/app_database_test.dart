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
}
