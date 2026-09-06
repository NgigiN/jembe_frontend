import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/domain/repositories/infrastructure_repository.dart';

/// Stream-based counterpart to `GetInfrastructure`, used by
/// `InfrastructureBloc` only when `OfflineConfig.enabled` is true
/// (`WatchInfrastructureEvent`). Not a `UseCase` (that base class is
/// Future-based) — this just forwards the repository's reactive stream so
/// the bloc doesn't depend on `InfrastructureRepository` directly.
class WatchInfrastructure {
  WatchInfrastructure(this.repository);
  final InfrastructureRepository repository;

  Stream<List<Infrastructure>> call() => repository.watchInfrastructures();
}
