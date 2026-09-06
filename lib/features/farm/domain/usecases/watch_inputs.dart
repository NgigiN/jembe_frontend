import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';

/// Stream-based counterpart to `GetInputs`, used by `InputBloc` only when
/// `OfflineConfig.enabled` is true (`WatchInputsEvent`). Not a `UseCase`
/// (that base class is Future-based) — this just forwards the repository's
/// reactive stream, scoped to `sourceType` exactly like the existing
/// `GetInputsEvent(sourceType:)`, so the bloc doesn't depend on
/// `InputRepository` directly.
class WatchInputs {
  WatchInputs(this.repository);
  final InputRepository repository;

  Stream<List<Input>> call({String? sourceType}) =>
      repository.watchInputs(sourceType: sourceType);
}
