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
    'opens at schema v2 with all 15 tables present and usable '
    '(insert + select a row on each of the 12 new offline mirrors)',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      expect(db.schemaVersion, 2);
      final now = DateTime(2026);

      await db
          .into(db.plants)
          .insert(
            PlantsCompanion.insert(
              clientUuid: 'plant-1',
              userId: 'u1',
              name: 'Maize',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.seasons)
          .insert(
            SeasonsCompanion.insert(
              clientUuid: 'season-1',
              userId: 'u1',
              name: '2026 Long Rains',
              plantId: 'plant-1',
              landId: 'land-1',
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.animals)
          .insert(
            AnimalsCompanion.insert(
              clientUuid: 'animal-1',
              userId: 'u1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.harvests)
          .insert(
            HarvestsCompanion.insert(
              clientUuid: 'harvest-1',
              seasonId: 'season-1',
              quantity: 12.5,
              unit: 'kg',
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.inputs)
          .insert(
            InputsCompanion.insert(
              clientUuid: 'input-1',
              sourceType: 'plant',
              sourceId: 'plant-1',
              type: 'fertilizer',
              cost: 500,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              clientUuid: 'activity-1',
              sourceType: 'plant',
              sourceId: 'plant-1',
              type: 'weeding',
              cost: 200,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.animalTypes)
          .insert(
            AnimalTypesCompanion.insert(
              clientUuid: 'animal-type-1',
              userId: 'u1',
              name: 'Dairy Cow',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.herds)
          .insert(
            HerdsCompanion.insert(
              clientUuid: 'herd-1',
              userId: 'u1',
              name: 'Main herd',
              animalTypeId: 'animal-type-1',
              location: 'North paddock',
              initialHeadCount: 10,
              currentHeadCount: 10,
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.infrastructures)
          .insert(
            InfrastructuresCompanion.insert(
              clientUuid: 'infra-1',
              userId: 'u1',
              type: 'Store',
              name: 'Grain store',
              location: 'North paddock',
              cost: 15000,
              date: now,
              notes: '',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.revenues)
          .insert(
            RevenuesCompanion.insert(
              clientUuid: 'revenue-1',
              userId: 'u1',
              source: 'harvest',
              sourceId: 'harvest-1',
              type: 'sale',
              quantity: 12.5,
              unitPrice: 50,
              total: 625,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.costCategories)
          .insert(
            CostCategoriesCompanion.insert(
              clientUuid: 'cost-category-1',
              name: 'Feed',
              type: 'animal',
              category: 'input',
              isDefault: true,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.herdActivities)
          .insert(
            HerdActivitiesCompanion.insert(
              clientUuid: 'herd-activity-1',
              herdId: 'herd-1',
              activityType: 'birth',
              count: 1,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        (await db.select(db.plants).get()).single.name,
        'Maize',
      );
      expect(
        (await db.select(db.seasons).get()).single.plantId,
        'plant-1',
      );
      expect(
        (await db.select(db.animals).get()).single.herdId,
        'herd-1',
      );
      expect(
        (await db.select(db.harvests).get()).single.quantity,
        12.5,
      );
      expect(
        (await db.select(db.inputs).get()).single.type,
        'fertilizer',
      );
      expect(
        (await db.select(db.activities).get()).single.type,
        'weeding',
      );
      expect(
        (await db.select(db.animalTypes).get()).single.name,
        'Dairy Cow',
      );
      expect(
        (await db.select(db.herds).get()).single.currentHeadCount,
        10,
      );
      expect(
        (await db.select(db.infrastructures).get()).single.type,
        'Store',
      );
      expect(
        (await db.select(db.revenues).get()).single.total,
        625,
      );
      expect(
        (await db.select(db.costCategories).get()).single.isDefault,
        true,
      );
      expect(
        (await db.select(db.herdActivities).get()).single.activityType,
        'birth',
      );

      await db.close();
    },
  );

  test(
    'wipeAll() clears every offline-first table (all 13 entity mirrors, '
    'Outbox, SyncCursor) in one go',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime(2026);

      // Seed a row in each table `wipeAll` targets.
      await db
          .into(db.lands)
          .insert(
            LandsCompanion.insert(
              clientUuid: 'cu-1',
              userId: 'u1',
              name: 'North',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.plants)
          .insert(
            PlantsCompanion.insert(
              clientUuid: 'plant-1',
              userId: 'u1',
              name: 'Maize',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.seasons)
          .insert(
            SeasonsCompanion.insert(
              clientUuid: 'season-1',
              userId: 'u1',
              name: '2026 Long Rains',
              plantId: 'plant-1',
              landId: 'cu-1',
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.animals)
          .insert(
            AnimalsCompanion.insert(
              clientUuid: 'animal-1',
              userId: 'u1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.harvests)
          .insert(
            HarvestsCompanion.insert(
              clientUuid: 'harvest-1',
              seasonId: 'season-1',
              quantity: 12.5,
              unit: 'kg',
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.inputs)
          .insert(
            InputsCompanion.insert(
              clientUuid: 'input-1',
              sourceType: 'plant',
              sourceId: 'plant-1',
              type: 'fertilizer',
              cost: 500,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              clientUuid: 'activity-1',
              sourceType: 'plant',
              sourceId: 'plant-1',
              type: 'weeding',
              cost: 200,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.animalTypes)
          .insert(
            AnimalTypesCompanion.insert(
              clientUuid: 'animal-type-1',
              userId: 'u1',
              name: 'Dairy Cow',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.herds)
          .insert(
            HerdsCompanion.insert(
              clientUuid: 'herd-1',
              userId: 'u1',
              name: 'Main herd',
              animalTypeId: 'animal-type-1',
              location: 'North paddock',
              initialHeadCount: 10,
              currentHeadCount: 10,
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.infrastructures)
          .insert(
            InfrastructuresCompanion.insert(
              clientUuid: 'infra-1',
              userId: 'u1',
              type: 'Store',
              name: 'Grain store',
              location: 'North paddock',
              cost: 15000,
              date: now,
              notes: '',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.revenues)
          .insert(
            RevenuesCompanion.insert(
              clientUuid: 'revenue-1',
              userId: 'u1',
              source: 'harvest',
              sourceId: 'harvest-1',
              type: 'sale',
              quantity: 12.5,
              unitPrice: 50,
              total: 625,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.costCategories)
          .insert(
            CostCategoriesCompanion.insert(
              clientUuid: 'cost-category-1',
              name: 'Feed',
              type: 'animal',
              category: 'input',
              isDefault: true,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.herdActivities)
          .insert(
            HerdActivitiesCompanion.insert(
              clientUuid: 'herd-activity-1',
              herdId: 'herd-1',
              activityType: 'birth',
              count: 1,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              entity: 'land',
              op: 'create',
              clientUuid: 'cu-1',
              updatedAt: now,
            ),
          );
      await db
          .into(db.syncCursor)
          .insert(
            SyncCursorCompanion.insert(
              entity: 'land',
              lastPulledAt: Value(now),
            ),
          );

      // Sanity check: every table actually has a row before wiping.
      expect(await db.select(db.lands).get(), hasLength(1));
      expect(await db.select(db.plants).get(), hasLength(1));
      expect(await db.select(db.seasons).get(), hasLength(1));
      expect(await db.select(db.animals).get(), hasLength(1));
      expect(await db.select(db.harvests).get(), hasLength(1));
      expect(await db.select(db.inputs).get(), hasLength(1));
      expect(await db.select(db.activities).get(), hasLength(1));
      expect(await db.select(db.animalTypes).get(), hasLength(1));
      expect(await db.select(db.herds).get(), hasLength(1));
      expect(await db.select(db.infrastructures).get(), hasLength(1));
      expect(await db.select(db.revenues).get(), hasLength(1));
      expect(await db.select(db.costCategories).get(), hasLength(1));
      expect(await db.select(db.herdActivities).get(), hasLength(1));
      expect(await db.select(db.outbox).get(), hasLength(1));
      expect(await db.select(db.syncCursor).get(), hasLength(1));

      await db.wipeAll();

      expect(await db.select(db.lands).get(), isEmpty);
      expect(await db.select(db.plants).get(), isEmpty);
      expect(await db.select(db.seasons).get(), isEmpty);
      expect(await db.select(db.animals).get(), isEmpty);
      expect(await db.select(db.harvests).get(), isEmpty);
      expect(await db.select(db.inputs).get(), isEmpty);
      expect(await db.select(db.activities).get(), isEmpty);
      expect(await db.select(db.animalTypes).get(), isEmpty);
      expect(await db.select(db.herds).get(), isEmpty);
      expect(await db.select(db.infrastructures).get(), isEmpty);
      expect(await db.select(db.revenues).get(), isEmpty);
      expect(await db.select(db.costCategories).get(), isEmpty);
      expect(await db.select(db.herdActivities).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await db.select(db.syncCursor).get(), isEmpty);

      await db.close();
    },
  );
}
