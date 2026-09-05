import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_repository.dart';

/// Stream-based counterpart to `GetAnimals`, used by `AnimalBloc` only when
/// `OfflineConfig.enabled` is true (`WatchAnimalsEvent`). Not a `UseCase`
/// (that base class is Future-based) — this just forwards the repository's
/// reactive stream so the bloc doesn't depend on `AnimalRepository` directly.
class WatchAnimals {
  WatchAnimals(this.repository);
  final AnimalRepository repository;

  Stream<List<Animal>> call() => repository.watchAnimals();
}
