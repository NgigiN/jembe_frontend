import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';

abstract class InputRepository {
  Future<Either<Failure, List<Input>>> getInputs({String? sourceType});

  /// Reactive stream of inputs, optionally scoped to [sourceType] (mirrors
  /// the existing `getInputs(sourceType:)` app-level filter).
  ///
  /// When the offline feature flag is on, each emission reflects the local
  /// mirror (`InputLocalDataSource.watchInputs`), with every [Input.id]
  /// equal to the row's stable `clientUuid` — see `InputRepositoryImpl` for
  /// why presentation keys on `clientUuid` rather than the server id. When
  /// the flag is off, this is unused by the app today; it still returns a
  /// single-emission stream so callers compile against one contract either
  /// way.
  Stream<List<Input>> watchInputs({String? sourceType});
  Future<Either<Failure, Input>> addInput(Input input);
  Future<Either<Failure, Input>> updateInput(Input input);
  Future<Either<Failure, void>> deleteInput(String id);
}
