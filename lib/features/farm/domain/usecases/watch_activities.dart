import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';

/// Stream-based counterpart to `GetActivities`, used by `ActivityBloc` only
/// when `OfflineConfig.enabled` is true (`WatchActivitiesEvent`). Not a
/// `UseCase` (that base class is Future-based) — this just forwards the
/// repository's reactive stream, scoped to `sourceType` exactly like the
/// existing `GetActivitiesEvent(sourceType:)`, so the bloc doesn't depend on
/// `ActivityRepository` directly.
class WatchActivities {
  WatchActivities(this.repository);
  final ActivityRepository repository;

  Stream<List<Activity>> call({String? sourceType}) =>
      repository.watchActivities(sourceType: sourceType);
}
