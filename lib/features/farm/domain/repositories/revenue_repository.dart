import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/revenue.dart';

abstract class RevenueRepository {
  /// [limit]/[cursor] drive the online infinite-scroll list path (P3-02a):
  /// they are threaded through only when the offline flag is off. The offline
  /// (`watchRevenues`) path ignores them — it mirrors the whole local store.
  Future<Either<Failure, List<Revenue>>> getRevenues({
    String? source,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? cursor,
  });

  /// Reactive stream of ALL revenues, UNFILTERED (no `source`/date scoping
  /// at this layer — see `RevenueBloc`'s in-memory filter doc).
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`RevenueLocalDataSource.watchRevenues`), with every
  /// [Revenue.id] equal to the row's stable `clientUuid` — see
  /// `RevenueRepositoryImpl` for why presentation keys on `clientUuid`
  /// rather than the server id. When the flag is off, this is unused by the
  /// app today; it still returns a single-emission stream so callers
  /// compile against one contract either way.
  Stream<List<Revenue>> watchRevenues();
  Future<Either<Failure, Revenue>> getRevenueById(String id);
  Future<Either<Failure, Revenue>> addRevenue({
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required DateTime date,
    double? total,
    String? notes,
  });
  Future<Either<Failure, Revenue>> updateRevenue({
    required String id,
    required String source,
    required String sourceId,
    required String type,
    required double quantity,
    required double unitPrice,
    required double total,
    required DateTime date,
    String? notes,
  });
  Future<Either<Failure, void>> deleteRevenue(String id);
}
