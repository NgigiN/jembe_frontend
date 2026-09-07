import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/utils/guard.dart';
import 'package:farm_tracker/features/farm/data/datasources/trash_remote_data_source.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';
import 'package:farm_tracker/features/farm/domain/repositories/trash_repository.dart';

/// Online-only: the trash/restore utility has no offline mirror (Phase 8 B2
/// scope — see the plan's "Offline interaction (sleeper risk)" note).
/// Always talks straight to [remoteDataSource]; callers (the bloc/page) gate
/// on `!OfflineConfig.enabled` before dispatching, exactly like
/// `DashboardRepositoryImpl`.
class TrashRepositoryImpl implements TrashRepository {
  TrashRepositoryImpl({required this.remoteDataSource});
  final TrashRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<TrashItem>>> getTrash() {
    return guard(
      remoteDataSource.getTrash,
      onUnexpected: (e) => 'Unexpected error: $e',
    );
  }

  /// Not routed through the shared `guard()` helper: a restore's 409
  /// ([ConflictException]) must surface as a distinct [ConflictFailure] so
  /// `TrashBloc` can keep the item in the list instead of removing it —
  /// `guard()` is shared by every other repository and deliberately left
  /// unaware of this trash-only exception type (see `ConflictException`'s
  /// class docs). Every other branch mirrors `guard()`'s mapping exactly.
  @override
  Future<Either<Failure, void>> restore({
    required String entity,
    required String id,
  }) async {
    try {
      await remoteDataSource.restore(entity: entity, id: id);
      return const Right(null);
    } on ConflictException catch (e) {
      return Left(ConflictFailure(e.message));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: $e'));
    }
  }
}
