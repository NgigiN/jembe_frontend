import 'package:farm_tracker/features/farm/domain/entities/harvest.dart';
import 'package:farm_tracker/features/farm/domain/repositories/harvest_repository.dart';

/// Stream-based counterpart to `GetHarvests`, used by `HarvestBloc` only
/// when `OfflineConfig.enabled` is true (`WatchHarvestsEvent`). Not a
/// `UseCase` (that base class is Future-based) — this just forwards the
/// repository's reactive stream, scoped to `seasonId` exactly like the
/// existing `GetHarvestsEvent(seasonId:)`, so the bloc doesn't depend on
/// `HarvestRepository` directly.
class WatchHarvests {
  WatchHarvests(this.repository);
  final HarvestRepository repository;

  Stream<List<Harvest>> call({String? seasonId}) =>
      repository.watchHarvests(seasonId: seasonId);
}
