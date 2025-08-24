import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/input.dart';
import '../repositories/input_repository.dart';

class UpdateInput implements UseCase<Input, UpdateInputParams> {
  final InputRepository repository;

  UpdateInput(this.repository);

  @override
  Future<Either<Failure, Input>> call(UpdateInputParams params) async {
    return await repository.updateInput(params.input);
  }
}

class UpdateInputParams {
  final Input input;

  UpdateInputParams({required this.input});
}
