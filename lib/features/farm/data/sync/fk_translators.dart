import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
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
