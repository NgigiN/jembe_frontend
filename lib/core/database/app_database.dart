import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/db_key_service.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

part 'app_database.g.dart';

/// Local mirror of the `Land` entity plus a sync header used by the
/// offline-first outbox/pull pipeline.
@DataClassName('LandRow')
class Lands extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  RealColumn get size => real().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get soilType => text().nullable()();
  TextColumn get tenureType => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Plant` entity plus the standard sync header.
@DataClassName('PlantRow')
class Plants extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get variety => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Season` entity plus the standard sync header.
@DataClassName('SeasonRow')
class Seasons extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get plantId => text()();
  TextColumn get landId => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Animal` entity plus the standard sync header.
@DataClassName('AnimalRow')
class Animals extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get animalTypeId => text()();
  TextColumn get herdId => text()();
  DateTimeColumn get birthDate => dateTime()();
  TextColumn get sex => text().nullable()();
  TextColumn get acquisitionSource => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Harvest` entity plus the standard sync header.
/// `Harvest` has no `userId` field; the entity is scoped through its
/// `seasonId` FK instead.
@DataClassName('HarvestRow')
class Harvests extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get seasonId => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get revenueId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Input` entity plus the standard sync header.
/// `Input` has no `userId` field; it is scoped through `sourceType` +
/// `sourceId` instead.
@DataClassName('InputRow')
class Inputs extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  IntColumn get animalId => integer().nullable()();
  TextColumn get type => text()();
  RealColumn get quantity => real().nullable()();
  RealColumn get cost => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Activity` entity plus the standard sync header.
/// `Activity` has no `userId` field; it is scoped through `sourceType` +
/// `sourceId` instead.
@DataClassName('ActivityRow')
class Activities extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  IntColumn get animalId => integer().nullable()();
  TextColumn get type => text()();
  TextColumn get details => text().nullable()();
  RealColumn get cost => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `AnimalType` entity plus the standard sync header.
@DataClassName('AnimalTypeRow')
class AnimalTypes extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Herd` entity plus the standard sync header.
@DataClassName('HerdRow')
class Herds extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get animalTypeId => text()();
  TextColumn get location => text()();
  IntColumn get initialHeadCount => integer()();
  IntColumn get currentHeadCount => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Infrastructure` entity plus the standard sync
/// header. Unlike most other entities, `notes` is non-nullable on the
/// domain model (defaults to `''`), so it is stored as a required column.
@DataClassName('InfrastructureRow')
class Infrastructures extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get location => text()();
  RealColumn get cost => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `Revenue` entity plus the standard sync header.
@DataClassName('RevenueRow')
class Revenues extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get source => text()();
  TextColumn get sourceId => text()();
  TextColumn get type => text()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `CostCategory` entity plus the standard sync
/// header. `CostCategory` has no `userId` and no timestamps of its own —
/// the header's `createdAt`/`updatedAt` are still present for schema
/// uniformity, but this entity won't participate in LWW at the syncer
/// level (see Task 9's bespoke `CostCategorySyncer`).
@DataClassName('CostCategoryRow')
class CostCategories extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  BoolColumn get isDefault => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// Local mirror of the `HerdActivity` entity plus the standard sync
/// header. `HerdActivity` has no `userId` and no `updatedAt` of its own —
/// the header's `updatedAt` is still present for schema uniformity, but
/// this entity won't participate in LWW at the syncer level (see Task 9's
/// bespoke `HerdActivitySyncer`).
@DataClassName('HerdActivityRow')
class HerdActivities extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get herdId => text()();
  TextColumn get activityType => text()();
  IntColumn get count => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
  BoolColumn get deletedLocally =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

/// FIFO queue of local mutations awaiting sync with the server.
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get op => text()();
  TextColumn get clientUuid => text()();
  TextColumn get payload => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Tracks the last successful pull timestamp per synced entity.
@DataClassName('SyncCursorRow')
class SyncCursor extends Table {
  TextColumn get entity => text()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}

@DriftDatabase(
  tables: [
    Lands,
    Plants,
    Seasons,
    Animals,
    Harvests,
    Inputs,
    Activities,
    AnimalTypes,
    Herds,
    Infrastructures,
    Revenues,
    CostCategories,
    HerdActivities,
    Outbox,
    SyncCursor,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.forTesting(QueryExecutor e) : super(e);

  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 only had Lands/Outbox/SyncCursor; create the 12 new offline
        // mirrors added in v2. Lands/Outbox/SyncCursor already exist and
        // must NOT be re-created here.
        await m.createTable(plants);
        await m.createTable(seasons);
        await m.createTable(animals);
        await m.createTable(harvests);
        await m.createTable(inputs);
        await m.createTable(activities);
        await m.createTable(animalTypes);
        await m.createTable(herds);
        await m.createTable(infrastructures);
        await m.createTable(revenues);
        await m.createTable(costCategories);
        await m.createTable(herdActivities);
      }
    },
  );

  /// Wipes every offline-first mirror — Lands and the 12 other entity
  /// mirrors, plus the outbox and sync cursors. Used to guarantee no other
  /// user's data (or in-flight mutations) survives a logout on a shared
  /// device. Runs inside a transaction so a crash mid-wipe can't leave a
  /// partial wipe (e.g. cursors cleared but stale rows left behind in one
  /// of the mirrors).
  ///
  /// After the wipe transaction commits, runs a `VACUUM` to actually reclaim
  /// the disk space freed by deleting every row (SQLite doesn't shrink the
  /// file on `DELETE` alone) — minimal retention hygiene, no periodic/
  /// scheduled cleanup. `VACUUM` cannot run inside a transaction, so it must
  /// happen after `transaction(...)` returns. It's best-effort: a `VACUUM`
  /// failure (e.g. no free disk space for the temporary copy it makes) must
  /// never break logout — the wipe itself already succeeded by this point.
  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(lands).go();
      await delete(plants).go();
      await delete(seasons).go();
      await delete(animals).go();
      await delete(harvests).go();
      await delete(inputs).go();
      await delete(activities).go();
      await delete(animalTypes).go();
      await delete(herds).go();
      await delete(infrastructures).go();
      await delete(revenues).go();
      await delete(costCategories).go();
      await delete(herdActivities).go();
      await delete(outbox).go();
      await delete(syncCursor).go();
    });

    try {
      await customStatement('VACUUM;');
    } on Object catch (e, st) {
      appLogger.error(
        LogCategory.general,
        'AppDatabase.wipeAll: VACUUM failed after the logout wipe '
        '(non-fatal — the wipe itself already succeeded)',
        e,
        st,
      );
    }
  }
}

/// Opens the local drift database, encrypted at rest with SQLite3MultipleCiphers.
///
/// Everything in this function — reading/generating the encryption key and
/// touching the database file at all — is deferred until this `LazyDatabase`
/// is actually opened (drift's first real query against [AppDatabase]). With
/// `OfflineConfig.enabled == false`, no repository ever issues that first
/// query, so none of this runs: no key generation, no secure-storage read,
/// no crypto work at startup (rule zero for this rollout).
///
/// The recipe follows drift 2.32's documented native-assets encryption
/// integration (https://drift.simonbinder.eu/platforms/encryption/): the
/// SQLite3MultipleCiphers library is bundled via the `hooks.user_defines.
/// sqlite3.source = sqlite3mc` block in pubspec.yaml (replacing the old
/// `sqlcipher_flutter_libs` native plugin), so no per-platform loader
/// override is needed — `package:sqlite3` loads the bundled cipher-enabled
/// library automatically on every isolate. The key is applied with
/// `PRAGMA key` inside [NativeDatabase.createInBackground]'s `setup`
/// callback, immediately after opening and before any other statement runs;
/// a debug-only [_debugCheckHasCipher] assertion first confirms the
/// cipher-enabled build is actually what got bundled.
///
/// Because [NativeDatabase.createInBackground] opens the database lazily on
/// a background isolate (only when drift's own machinery first calls
/// `ensureOpen`), a bad key would otherwise only surface much later, on
/// whatever query happens to trigger that — nowhere near this function, and
/// with no chance to recover. So this function proves the key works itself,
/// first, via [_canOpenWithKey]'s direct (non-isolate) open-with-canary
/// check, before ever constructing the real connection. If that check
/// fails — key lost, or the file otherwise unreadable — the database file
/// is wiped, the key is discarded and regenerated, and the check is retried
/// once against the fresh (necessarily empty) file. The server is the
/// source of truth for this offline-first pilot, so wiping and re-syncing
/// is the approved recovery: any unsynced outbox writes lived in that same
/// encrypted file and are unrecoverable regardless of which way this fails.
LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  if (!dir.existsSync()) {
    // sqlite3 can create the database file itself but not its parent
    // directory; the preflight open below needs this to already exist
    // (drift's own background-isolate open would otherwise be the only
    // thing creating it, too late for the preflight check).
    dir.createSync(recursive: true);
  }
  final dbFile = File(p.join(dir.path, 'shamba.sqlite'));
  final keyService = DbKeyService();

  var key = await keyService.getOrCreateKey();

  if (!_canOpenWithKey(dbFile, key)) {
    appLogger.warning(
      LogCategory.general,
      'Local database unreadable with the stored encryption key; wiping '
      'and re-provisioning a fresh encrypted database (server re-sync).',
    );
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    await keyService.deleteKey();
    key = await keyService.getOrCreateKey();

    if (!_canOpenWithKey(dbFile, key)) {
      // A fresh file with a freshly-generated key must always open; if it
      // doesn't, the problem isn't the key (disk full, permissions, a
      // corrupt native SQLite library, ...) and retrying again won't help.
      throw StateError(
        'Unable to open the local database even after wiping it and '
        'generating a fresh encryption key.',
      );
    }
  }

  return NativeDatabase.createInBackground(
    dbFile,
    setup: (rawDb) {
      // Assert (debug builds only) that the bundled SQLite is the
      // cipher-enabled SQLite3MultipleCiphers build before relying on
      // `PRAGMA key`; on a stock-SQLite build the key would be silently
      // ignored, leaving the file unencrypted.
      assert(_debugCheckHasCipher(rawDb));
      // PRAGMA key first, then a canary read of the schema — touching it
      // now proves the key is correct. A wrong/missing key throws here, on
      // the background isolate, as defense in depth on top of the
      // preflight check above.
      rawDb
        ..execute("PRAGMA key = '$key';")
        ..select('SELECT count(*) FROM sqlite_master;');
    },
  );
});

/// Returns whether [database] was opened against a cipher-enabled SQLite
/// build (SQLite3MultipleCiphers). Stock SQLite has no `cipher` pragma, so an
/// empty result means encryption is unavailable and `PRAGMA key` would be a
/// silent no-op. Used only in a debug `assert` — see [_openConnection].
bool _debugCheckHasCipher(sqlite3_lib.Database database) =>
    database.select('PRAGMA cipher;').isNotEmpty;

/// Opens [dbFile] directly with [key] applied — bypassing drift and the
/// background isolate entirely — and proves the key actually decrypts it by
/// running a canary query against the schema. Returns `false` if opening or
/// the canary throws (wrong/missing key, or a corrupt file); `true` if the
/// key works. Always closes the connection it opens.
bool _canOpenWithKey(File dbFile, String key) {
  sqlite3_lib.Database? db;
  try {
    db = sqlite3_lib.sqlite3.open(dbFile.path)
      ..execute("PRAGMA key = '$key';")
      ..select('SELECT count(*) FROM sqlite_master;');
    return true;
  } catch (e) {
    // Never pass the raw exception to the logger here: a SqliteException's
    // toString() embeds `causingStatement` — the SQL text of whichever
    // statement was executing — and the `PRAGMA key = '$key';` above runs
    // inside this same try. Logging `e` (even just its message) risks
    // logging the key itself in plaintext, and `appLogger.warning` emits
    // unconditionally, in release builds too. Log only the exception's
    // type, never the exception object.
    appLogger.warning(
      LogCategory.general,
      'Preflight open of the local database failed (${e.runtimeType})',
    );
    return false;
  } finally {
    db?.dispose();
  }
}
