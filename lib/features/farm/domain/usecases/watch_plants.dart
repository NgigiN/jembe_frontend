import 'package:farm_tracker/features/farm/domain/entities/plant.dart';
import 'package:farm_tracker/features/farm/domain/repositories/plant_repository.dart';

/// Stream-based counterpart to `GetPlants`, used by `PlantBloc` only when
/// `OfflineConfig.enabled` is true (`WatchPlantsEvent`). Not a `UseCase`
/// (that base class is Future-based) — this just forwards the repository's
/// reactive stream so the bloc doesn't depend on `PlantRepository` directly.
class WatchPlants {
  WatchPlants(this.repository);
  final PlantRepository repository;

  Stream<List<Plant>> call() => repository.watchPlants();
}
