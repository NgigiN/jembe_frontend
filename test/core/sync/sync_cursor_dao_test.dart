import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncCursorDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SyncCursorDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncCursorDao', () {
    test('get returns null for an entity that was never set', () async {
      expect(await dao.get('land'), isNull);
    });

    test('set then get round-trips the same instant', () async {
      final at = DateTime.utc(2026, 3, 4, 10, 30);

      await dao.set('land', at);

      final read = await dao.get('land');
      expect(read, isNotNull);
      // drift returns local-zone DateTimes; compare by instant, never ==.
      expect(read!.isAtSameMomentAs(at), isTrue);
    });

    test('set upserts: a second set overwrites the first', () async {
      final first = DateTime.utc(2026);
      final second = DateTime.utc(2026, 6, 1, 12);

      await dao.set('land', first);
      await dao.set('land', second);

      final read = await dao.get('land');
      expect(read!.isAtSameMomentAs(second), isTrue);
    });

    test('cursors for different entities are independent', () async {
      final landAt = DateTime.utc(2026, 2, 2, 8);
      final cropAt = DateTime.utc(2026, 2, 3, 9);

      await dao.set('land', landAt);
      await dao.set('crop', cropAt);

      expect((await dao.get('land'))!.isAtSameMomentAs(landAt), isTrue);
      expect((await dao.get('crop'))!.isAtSameMomentAs(cropAt), isTrue);
    });
  });
}
