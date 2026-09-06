import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  Future<void> wipeAll() {
    return transaction(() async {
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
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(
    File(p.join(dir.path, 'shamba.sqlite')),
  );
});
