import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';
import 'package:farm_tracker/features/farm/domain/repositories/revenue_repository.dart';

/// Stream-based counterpart to `GetRevenues`, used by `RevenueBloc` only
/// when `OfflineConfig.enabled` is true (`WatchRevenuesEvent`). Not a
/// `UseCase` (that base class is Future-based) — this just forwards the
/// repository's reactive, UNFILTERED stream so the bloc doesn't depend on
/// `RevenueRepository` directly. The `source`/date filter is applied
/// in-memory by the bloc (see `RevenueBloc`'s R1 doc), not here.
class WatchRevenues {
  WatchRevenues(this.repository);
  final RevenueRepository repository;

  Stream<List<Revenue>> call() => repository.watchRevenues();
}
