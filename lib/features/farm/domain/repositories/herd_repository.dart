import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';

abstract class HerdRepository {
  /// [limit]/[cursor] drive the online infinite-scroll list path (P3-02a):
  /// they are threaded through only when the offline flag is off. The offline
  /// (`watchHerds`) path ignores them — it mirrors the whole local store.
  Future<Either<Failure, List<Herd>>> getHerds({int? limit, int? cursor});

  /// Reactive stream of herds.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`HerdLocalDataSource.watchHerds`), with every [Herd.id] equal
  /// to the row's stable `clientUuid` — see `HerdRepositoryImpl` for why
  /// presentation keys on `clientUuid` rather than the server id. When the
  /// flag is off, this is unused by the app today; it still returns a
  /// single-emission stream so callers compile against one contract either
  /// way.
  Stream<List<Herd>> watchHerds();
  Future<Either<Failure, Herd>> addHerd(
    String name,
    String animalTypeId,
    String location,
    String userId,
    int initialHeadCount, {
    required DateTime startDate,
    DateTime? endDate,
  });
  Future<Either<Failure, Herd>> updateHerd(
    String id,
    String name,
    String animalTypeId,
    String location,
    int initialHeadCount, {
    required DateTime startDate,
    DateTime? endDate,
  });
  Future<Either<Failure, void>> deleteHerd(String id);
}
