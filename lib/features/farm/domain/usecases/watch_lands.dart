import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/repositories/land_repository.dart';

/// Stream-based counterpart to `GetLands`, used by `LandBloc` only when
/// `OfflineConfig.enabled` is true (`WatchLandsEvent`). Not a `UseCase`
/// (that base class is Future-based) — this just forwards the repository's
/// reactive stream so the bloc doesn't depend on `LandRepository` directly.
class WatchLands {
  WatchLands(this.repository);
  final LandRepository repository;

  Stream<List<Land>> call() => repository.watchLands();
}
