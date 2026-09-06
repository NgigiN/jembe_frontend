import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';

abstract class InfrastructureRepository {
  Future<Either<Failure, List<Infrastructure>>> getInfrastructures();

  /// Reactive stream of infrastructure rows.
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`InfrastructureLocalDataSource.watchInfrastructures`), with
  /// every [Infrastructure.id] equal to the row's stable `clientUuid` — see
  /// `InfrastructureRepositoryImpl` for why presentation keys on
  /// `clientUuid` rather than the server id. When the flag is off, this is
  /// unused by the app today; it still returns a single-emission stream so
  /// callers compile against one contract either way.
  Stream<List<Infrastructure>> watchInfrastructures();
  Future<Either<Failure, Infrastructure>> addInfrastructure(
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String userId,
    String? notes,
  );
  Future<Either<Failure, Infrastructure>> updateInfrastructure(
    String id,
    String type,
    String name,
    String location,
    double cost,
    DateTime date,
    String? notes,
  );
  Future<Either<Failure, void>> deleteInfrastructure(String id);
}
