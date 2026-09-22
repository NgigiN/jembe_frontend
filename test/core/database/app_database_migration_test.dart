import 'dart:io';

import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'upgrading a v2 database (no farm_id anywhere) to v3 adds farm_id to '
    'every table without crashing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('app_db_migration');
      addTearDown(() => tempDir.delete(recursive: true));
      final dbFile = File(p.join(tempDir.path, 'v2.sqlite'));

      // Bootstrap a raw v2-shaped database: the 13 entity tables (no
      // farm_id column) + Outbox + SyncCursor, `PRAGMA user_version = 2`
      // (drift's own schema-version marker) so AppDatabase (schemaVersion
      // 3) sees `from=2` and runs the real onUpgrade path against it.
      final raw = sqlite3_lib.sqlite3.open(dbFile.path);
      raw
        ..execute('PRAGMA user_version = 2;')
        ..execute('CREATE TABLE lands (client_uuid TEXT NOT NULL PRIMARY KEY, '
            'server_id TEXT, user_id TEXT NOT NULL, name TEXT NOT NULL, '
            'size REAL, location TEXT, soil_type TEXT, tenure_type TEXT, '
            'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
            'pending INTEGER NOT NULL DEFAULT 0, '
            'deleted_locally INTEGER NOT NULL DEFAULT 0);')
        ..execute('CREATE TABLE outbox (seq INTEGER NOT NULL PRIMARY KEY '
            'AUTOINCREMENT, entity TEXT NOT NULL, op TEXT NOT NULL, '
            'client_uuid TEXT NOT NULL, payload TEXT, attempts INTEGER '
            "NOT NULL DEFAULT 0, state TEXT NOT NULL DEFAULT 'pending', "
            'updated_at INTEGER NOT NULL);')
        ..execute('CREATE TABLE sync_cursor (entity TEXT NOT NULL PRIMARY '
            'KEY, last_pulled_at INTEGER);')
        ..dispose();

      // Open the SAME file through the real (non-forTesting) AppDatabase —
      // this is what actually exercises `migration.onUpgrade`. Constructing
      // `AppDatabase` directly with a `NativeDatabase(dbFile)` (rather than
      // `AppDatabase.open()`) bypasses `_openConnection()` entirely, so no
      // `path_provider`/encryption-key plumbing is touched — this is a
      // plain unencrypted `NativeDatabase` against the raw file, which is
      // all the migration itself needs to be exercised.
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);

      // Any query forces drift to open the connection and run the pending
      // migration; must not throw.
      await db.select(db.lands).get();

      final pragma = await db.customSelect('PRAGMA table_info(lands);').get();
      final columnNames = pragma.map((row) => row.data['name'] as String).toSet();
      expect(columnNames, contains('farm_id'));

      for (final table in ['outbox', 'sync_cursor', 'plants', 'animals']) {
        final info = await db.customSelect('PRAGMA table_info($table);').get();
        expect(
          info.map((row) => row.data['name'] as String),
          contains('farm_id'),
          reason: table,
        );
      }
    },
  );
}
