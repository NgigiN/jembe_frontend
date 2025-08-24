import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/input_repository.dart';

class DeleteInput implements UseCase<void, DeleteInputParams> {
  final InputRepository repository;

  DeleteInput(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteInputParams params) async {
    return await repository.deleteInput(params.id);
  }
}

class DeleteInputParams {
  final String id;

  DeleteInputParams({required this.id});
}
