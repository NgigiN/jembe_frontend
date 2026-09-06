import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
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
}
