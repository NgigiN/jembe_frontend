import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/repositories/animal_type_repository.dart';

/// Stream-based counterpart to `GetAnimalTypes`, used by `AnimalTypeBloc`
/// only when `OfflineConfig.enabled` is true (`WatchAnimalTypesEvent`). Not
/// a `UseCase` (that base class is Future-based) — this just forwards the
/// repository's reactive stream so the bloc doesn't depend on
/// `AnimalTypeRepository` directly.
class WatchAnimalTypes {
  WatchAnimalTypes(this.repository);
  final AnimalTypeRepository repository;

  Stream<List<AnimalType>> call() => repository.watchAnimalTypes();
}
