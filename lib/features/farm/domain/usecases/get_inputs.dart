import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_inputs_params.dart';

class GetInputs implements UseCase<List<Input>, GetInputsParams> {
  GetInputs(this.repository);
  final InputRepository repository;

  @override
  Future<Either<Failure, List<Input>>> call(GetInputsParams params) async {
    return repository.getInputs(sourceType: params.sourceType);
  }
}
