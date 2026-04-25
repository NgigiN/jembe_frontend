import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';

abstract class InputRepository {
  Future<Either<Failure, List<Input>>> getInputs({String? sourceType});
  Future<Either<Failure, Input>> addInput(Input input);
  Future<Either<Failure, Input>> updateInput(Input input);
  Future<Either<Failure, void>> deleteInput(String id);
}
