import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';

abstract class ActivityRepository {
  Future<Either<Failure, List<Activity>>> getActivities({String? sourceType});

  /// Reactive stream of activities, optionally scoped to [sourceType]
  /// (mirrors the existing `getActivities(sourceType:)` app-level filter).
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`ActivityLocalDataSource.watchActivities`), with every
  /// [Activity.id] equal to the row's stable `clientUuid` — see
  /// `ActivityRepositoryImpl` for why presentation keys on `clientUuid`
  /// rather than the server id. When the flag is off, this is unused by the
  /// app today; it still returns a single-emission stream so callers
  /// compile against one contract either way.
  Stream<List<Activity>> watchActivities({String? sourceType});
  Future<Either<Failure, Activity>> addActivity(Activity activity);
  Future<Either<Failure, Activity>> updateActivity(Activity activity);
  Future<Either<Failure, void>> deleteActivity(String id);
}
