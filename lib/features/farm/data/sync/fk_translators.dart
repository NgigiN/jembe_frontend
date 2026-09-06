import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/features/farm/data/models/activity_model.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/models/harvest_model.dart';
import 'package:farm_tracker/features/farm/data/models/herd_model.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/models/revenue_model.dart';
import 'package:farm_tracker/features/farm/data/models/season_model.dart';

/// Resolves one child FK field for a push. Returns [value] unchanged when it's
/// empty (no FK) or already a numeric server id; resolves a parent client_uuid
/// to its server id via [resolver]; throws [SyncDependencyException] when the
/// parent has not synced yet, so `SyncEngine` parks the child for a later pass.
Future<String> resolveFkOrThrow(
  FkResolver resolver,
  String parentEntity,
  String value,
) async {
  if (value.isEmpty) return value;
  if (int.tryParse(value) != null) return value; // already a server id
  final serverId = await resolver.resolve(parentEntity, value);
  if (serverId == null) throw SyncDependencyException();
  return serverId;
}

/// `season` parents: `plant` (`plant_id`) and `land` (`land_id`).
Future<SeasonModel> translateSeasonFks(SeasonModel m, FkResolver r) async {
  final plantId = await resolveFkOrThrow(r, 'plant', m.plantId);
  final landId = await resolveFkOrThrow(r, 'land', m.landId);
  return m.withResolvedFks(plantId: plantId, landId: landId);
}

/// `animal` parents: `animal_type` (`animal_type_id`) + `herd` (`herd_id`).
Future<AnimalModel> translateAnimalFks(AnimalModel m, FkResolver r) async {
  final animalTypeId = await resolveFkOrThrow(r, 'animal_type', m.animalTypeId);
  final herdId = await resolveFkOrThrow(r, 'herd', m.herdId);
  return m.withResolvedFks(animalTypeId: animalTypeId, herdId: herdId);
}

/// `harvest` parents: `season` (`season_id`) + optional `revenue` (`revenue_id`).
Future<HarvestModel> translateHarvestFks(HarvestModel m, FkResolver r) async {
  final seasonId = await resolveFkOrThrow(r, 'season', m.seasonId);
  final revenueId = m.revenueId == null
      ? null
      : await resolveFkOrThrow(r, 'revenue', m.revenueId!);
  return m.withResolvedFks(seasonId: seasonId, revenueId: revenueId);
}

/// `herd` parent: `animal_type` (`animal_type_id`).
Future<HerdModel> translateHerdFks(HerdModel m, FkResolver r) async {
  final animalTypeId = await resolveFkOrThrow(r, 'animal_type', m.animalTypeId);
  return m.withResolvedFks(animalTypeId: animalTypeId);
}

/// `input`/`activity` polymorphic `source_id` parent: `'plant'` sourceType ->
/// `season`; `'animal'` sourceType -> `herd`.
// P4: animal_id (int?) can't carry a client_uuid — synced-animal-only; a
// String migration is a later phase.
Future<InputModel> translateInputFks(InputModel m, FkResolver r) async {
  final parent = m.sourceType == 'animal' ? 'herd' : 'season';
  final sourceId = await resolveFkOrThrow(r, parent, m.sourceId);
  return m.withResolvedFks(sourceId: sourceId);
}

/// `input`/`activity` polymorphic `source_id` parent (see [translateInputFks]).
// P4: animal_id (int?) can't carry a client_uuid — synced-animal-only; a
// String migration is a later phase.
Future<ActivityModel> translateActivityFks(ActivityModel m, FkResolver r) async {
  final parent = m.sourceType == 'animal' ? 'herd' : 'season';
  final sourceId = await resolveFkOrThrow(r, parent, m.sourceId);
  return m.withResolvedFks(sourceId: sourceId);
}

/// `revenue` polymorphic `source_id` parent: same `'plant'`/`'animal'`
/// branches as input/activity, but the discriminator field is `source`
/// (not `sourceType`).
Future<RevenueModel> translateRevenueFks(RevenueModel m, FkResolver r) async {
  final parent = m.source == 'animal' ? 'herd' : 'season';
  final sourceId = await resolveFkOrThrow(r, parent, m.sourceId);
  return m.withResolvedFks(sourceId: sourceId);
}
