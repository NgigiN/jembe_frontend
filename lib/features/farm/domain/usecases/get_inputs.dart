import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/input.dart';
import '../repositories/input_repository.dart';
import 'get_inputs_params.dart';

class GetInputs implements UseCase<List<Input>, GetInputsParams> {
  final InputRepository repository;

  GetInputs(this.repository);

  @override
  Future<Either<Failure, List<Input>>> call(GetInputsParams params) async {
    return await repository.getInputs(sourceType: params.sourceType);
  }
}
