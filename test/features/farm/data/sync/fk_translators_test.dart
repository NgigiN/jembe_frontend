import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
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
}
