import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/repositories/season_repository.dart';

/// Stream-based counterpart to `GetSeasons`, used by `SeasonBloc` only when
/// `OfflineConfig.enabled` is true (`WatchSeasonsEvent`). Not a `UseCase`
/// (that base class is Future-based) — this just forwards the repository's
/// reactive stream so the bloc doesn't depend on `SeasonRepository`
/// directly.
class WatchSeasons {
  WatchSeasons(this.repository);
  final SeasonRepository repository;

  Stream<List<Season>> call() => repository.watchSeasons();
}
