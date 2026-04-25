import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/repositories/input_repository.dart';

class DeleteInput implements UseCase<void, DeleteInputParams> {
  DeleteInput(this.repository);
  final InputRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteInputParams params) async {
    return repository.deleteInput(params.id);
  }
}

class DeleteInputParams {
  DeleteInputParams({required this.id});
  final String id;
}
