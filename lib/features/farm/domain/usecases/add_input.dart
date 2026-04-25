import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';

class AddInput implements UseCase<Input, AddInputParams> {
  AddInput(this.repository);
  final InputRepository repository;

  @override
  Future<Either<Failure, Input>> call(AddInputParams params) async {
    return repository.addInput(params.input);
  }
}

class AddInputParams {
  AddInputParams({required this.input});
  final Input input;
}
