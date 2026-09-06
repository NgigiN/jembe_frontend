import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_repository.dart';

/// Stream-based counterpart to `GetHerds`, used by `HerdBloc` only when
/// `OfflineConfig.enabled` is true (`WatchHerdsEvent`). Not a `UseCase`
/// (that base class is Future-based) — this just forwards the repository's
/// reactive stream so the bloc doesn't depend on `HerdRepository` directly.
class WatchHerds {
  WatchHerds(this.repository);
  final HerdRepository repository;

  Stream<List<Herd>> call() => repository.watchHerds();
}
