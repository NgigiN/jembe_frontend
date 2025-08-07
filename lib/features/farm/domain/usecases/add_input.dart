import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/input.dart';
import '../repositories/input_repository.dart';

class AddInput implements UseCase<Input, AddInputParams> {
  final InputRepository repository;

  AddInput(this.repository);

  @override
  Future<Either<Failure, Input>> call(AddInputParams params) async {
    return await repository.addInput(params.input);
  }
}

class AddInputParams {
  final Input input;

  AddInputParams({required this.input});
}
