import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';
import 'package:farm_tracker/features/farm/data/sync/fk_translators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFkOrThrow', () {
    test('leaves an already-numeric server id untouched', () async {
      expect(await resolveFkOrThrow(FkResolver(const {}), 'plant', '42'), '42');
    });
    test('leaves an empty value untouched (no FK set)', () async {
      expect(await resolveFkOrThrow(FkResolver(const {}), 'plant', ''), '');
    });
    test('resolves a parent client_uuid to its server id', () async {
      final r = FkResolver(const {})..record('plant', 'plant-uuid', '7');
      expect(await resolveFkOrThrow(r, 'plant', 'plant-uuid'), '7');
    });
    test('throws SyncDependencyException when the parent is unsynced', () async {
      expect(
        () => resolveFkOrThrow(FkResolver(const {}), 'plant', 'plant-uuid'),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateSeasonFks', () {
    // Build a SeasonModel via its `create` factory (see season_model.dart)
    // with plantId/landId set to the PARENT client uuids.
    SeasonModel unsyncedSeason() => SeasonModel.create(
          userId: 'user-1',
          name: 'Season 1',
          plantId: 'plant-uuid',
          landId: 'land-uuid',
          startDate: DateTime(2026, 1, 1),
        );

    test('translates both parent uuids to their server ids', () async {
      final r = FkResolver(const {})
        ..record('plant', 'plant-uuid', '10')
        ..record('land', 'land-uuid', '20');
      final out = await translateSeasonFks(unsyncedSeason(), r);
      expect(out.plantId, '10');
      expect(out.landId, '20');
    });

    test('parks (throws) when the plant has not synced', () async {
      final r = FkResolver(const {})..record('land', 'land-uuid', '20');
      expect(
        () => translateSeasonFks(unsyncedSeason(), r),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateAnimalFks', () {
    AnimalModel unsyncedAnimal({String herdId = 'herd-uuid'}) =>
        AnimalModel.create(
          userId: 'user-1',
          name: 'Animal 1',
          animalTypeId: 'at-uuid',
          herdId: herdId,
          birthDate: DateTime(2026, 1, 1),
        );

    test('translates animal_type + herd parent uuids to server ids', () async {
      final r = FkResolver(const {})
        ..record('animal_type', 'at-uuid', '3')
        ..record('herd', 'herd-uuid', '5');
      final out = await translateAnimalFks(unsyncedAnimal(), r);
      expect(out.animalTypeId, '3');
      expect(out.herdId, '5');
    });

    test('parks when the animal_type is unsynced', () async {
      expect(
        () => translateAnimalFks(
          unsyncedAnimal(herdId: ''),
          FkResolver(const {}),
        ),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateHarvestFks', () {
    HarvestModel unsyncedHarvest() => HarvestModel.create(
          seasonId: 'season-uuid',
          quantity: 10,
          unit: 'kg',
          date: DateTime(2026, 1, 1),
        );

    test('translates the season parent uuid to its server id', () async {
      final r = FkResolver(const {})..record('season', 'season-uuid', '7');
      final out = await translateHarvestFks(unsyncedHarvest(), r);
      expect(out.seasonId, '7');
    });

    test('a null revenueId is left null', () async {
      final r = FkResolver(const {})..record('season', 'season-uuid', '7');
      final out = await translateHarvestFks(unsyncedHarvest(), r);
      expect(out.revenueId, isNull);
    });

    test('translates a non-null revenue parent uuid to its server id', () async {
      final withRevenue = unsyncedHarvest().withResolvedFks(
        revenueId: 'revenue-uuid',
      );
      final r = FkResolver(const {})
        ..record('season', 'season-uuid', '7')
        ..record('revenue', 'revenue-uuid', '11');
      final out = await translateHarvestFks(withRevenue, r);
      expect(out.revenueId, '11');
    });

    test('parks when the season has not synced', () async {
      expect(
        () => translateHarvestFks(unsyncedHarvest(), FkResolver(const {})),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateHerdFks', () {
    HerdModel unsyncedHerd() => HerdModel.create(
          userId: 'user-1',
          name: 'Herd 1',
          animalTypeId: 'at-uuid',
          location: 'Field A',
          initialHeadCount: 4,
          startDate: DateTime(2026, 1, 1),
        );

    test('translates the animal_type parent uuid to its server id', () async {
      final r = FkResolver(const {})..record('animal_type', 'at-uuid', '9');
      final out = await translateHerdFks(unsyncedHerd(), r);
      expect(out.animalTypeId, '9');
    });

    test('parks when the animal_type has not synced', () async {
      expect(
        () => translateHerdFks(unsyncedHerd(), FkResolver(const {})),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateInputFks', () {
    // Polymorphic source_id: 'plant' source_type -> season parent, 'animal'
    // source_type -> herd parent. animal_id (int?) is untouched — out of P4
    // scope (see InputModel's TODO note).
    InputModel unsyncedInput({
      String sourceType = 'plant',
      String sourceId = 'season-uuid',
      int? animalId,
    }) => InputModel.create(
      sourceType: sourceType,
      sourceId: sourceId,
      animalId: animalId,
      type: 'Fertilizer',
      cost: 100,
      date: DateTime(2026, 1, 1),
    );

    test('plant source -> resolves source_id against season', () async {
      final r = FkResolver(const {})..record('season', 'season-uuid', '8');
      final out = await translateInputFks(unsyncedInput(), r);
      expect(out.sourceId, '8');
    });

    test('animal source -> resolves source_id against herd', () async {
      final r = FkResolver(const {})..record('herd', 'herd-uuid', '9');
      final out = await translateInputFks(
        unsyncedInput(sourceType: 'animal', sourceId: 'herd-uuid', animalId: 0),
        r,
      );
      expect(out.sourceId, '9');
    });

    test('parks when the season parent is unsynced', () async {
      expect(
        () => translateInputFks(unsyncedInput(), FkResolver(const {})),
        throwsA(isA<SyncDependencyException>()),
      );
    });

    test('parks when the herd parent is unsynced', () async {
      expect(
        () => translateInputFks(
          unsyncedInput(sourceType: 'animal', sourceId: 'herd-uuid'),
          FkResolver(const {}),
        ),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateActivityFks', () {
    // Same two branches as translateInputFks (discriminator: sourceType).
    ActivityModel unsyncedActivity({
      String sourceType = 'plant',
      String sourceId = 'season-uuid',
      int? animalId,
    }) => ActivityModel.create(
      sourceType: sourceType,
      sourceId: sourceId,
      animalId: animalId,
      type: 'Weeding',
      cost: 50,
      date: DateTime(2026, 1, 1),
    );

    test('plant source -> resolves source_id against season', () async {
      final r = FkResolver(const {})..record('season', 'season-uuid', '12');
      final out = await translateActivityFks(unsyncedActivity(), r);
      expect(out.sourceId, '12');
    });

    test('animal source -> resolves source_id against herd', () async {
      final r = FkResolver(const {})..record('herd', 'herd-uuid', '13');
      final out = await translateActivityFks(
        unsyncedActivity(
          sourceType: 'animal',
          sourceId: 'herd-uuid',
          animalId: 0,
        ),
        r,
      );
      expect(out.sourceId, '13');
    });

    test('parks when the season parent is unsynced', () async {
      expect(
        () => translateActivityFks(unsyncedActivity(), FkResolver(const {})),
        throwsA(isA<SyncDependencyException>()),
      );
    });

    test('parks when the herd parent is unsynced', () async {
      expect(
        () => translateActivityFks(
          unsyncedActivity(sourceType: 'animal', sourceId: 'herd-uuid'),
          FkResolver(const {}),
        ),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });

  group('translateRevenueFks', () {
    // Same two branches, but the discriminator field is `source`, not
    // `sourceType`.
    RevenueModel unsyncedRevenue({
      String source = 'plant',
      String sourceId = 'season-uuid',
    }) => RevenueModel.create(
      source: source,
      sourceId: sourceId,
      type: 'Maize Harvest',
      quantity: 10,
      unitPrice: 50,
      date: DateTime(2026, 1, 1),
    );

    test('plant source -> resolves source_id against season', () async {
      final r = FkResolver(const {})..record('season', 'season-uuid', '21');
      final out = await translateRevenueFks(unsyncedRevenue(), r);
      expect(out.sourceId, '21');
    });

    test('animal source -> resolves source_id against herd', () async {
      final r = FkResolver(const {})..record('herd', 'herd-uuid', '22');
      final out = await translateRevenueFks(
        unsyncedRevenue(source: 'animal', sourceId: 'herd-uuid'),
        r,
      );
      expect(out.sourceId, '22');
    });

    test('parks when the season parent is unsynced', () async {
      expect(
        () => translateRevenueFks(unsyncedRevenue(), FkResolver(const {})),
        throwsA(isA<SyncDependencyException>()),
      );
    });

    test('parks when the herd parent is unsynced', () async {
      expect(
        () => translateRevenueFks(
          unsyncedRevenue(source: 'animal', sourceId: 'herd-uuid'),
          FkResolver(const {}),
        ),
        throwsA(isA<SyncDependencyException>()),
      );
    });
  });
}
