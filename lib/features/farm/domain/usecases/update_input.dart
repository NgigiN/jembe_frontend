import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';

class UpdateInput implements UseCase<Input, UpdateInputParams> {
  UpdateInput(this.repository);
  final InputRepository repository;

  @override
  Future<Either<Failure, Input>> call(UpdateInputParams params) async {
    return repository.updateInput(params.input);
  }
}

class UpdateInputParams {
  UpdateInputParams({required this.input});
  final Input input;
}
