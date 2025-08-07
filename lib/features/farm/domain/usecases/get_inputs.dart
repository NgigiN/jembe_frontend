import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/input.dart';
import '../repositories/input_repository.dart';

class GetInputs implements UseCase<List<Input>, NoParams> {
  final InputRepository repository;

  GetInputs(this.repository);

  @override
  Future<Either<Failure, List<Input>>> call(NoParams params) async {
    return await repository.getInputs();
  }
}
