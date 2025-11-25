import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/input.dart';

abstract class InputRepository {
  Future<Either<Failure, List<Input>>> getInputs({String? sourceType});
  Future<Either<Failure, Input>> addInput(Input input);
  Future<Either<Failure, Input>> updateInput(Input input);
  Future<Either<Failure, void>> deleteInput(String id);
}
