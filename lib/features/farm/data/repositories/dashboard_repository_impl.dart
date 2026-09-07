import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/utils/guard.dart';
import 'package:farm_tracker/features/farm/data/datasources/dashboard_remote_data_source.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/domain/repositories/dashboard_repository.dart';

/// Online-only: the dashboard aggregate has no offline mirror (Phase 8 B1
/// scope — see plan). Always talks straight to [remoteDataSource]; callers
/// (blocs/pages) gate dispatching the fetch itself on
/// `!OfflineConfig.enabled`, exactly like `AnalysisRepositoryImpl`.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required this.remoteDataSource});
  final DashboardRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, Dashboard>> getDashboard() {
    return guard(
      remoteDataSource.getDashboard,
      onUnexpected: (e) => 'Unexpected error: $e',
    );
  }
}
