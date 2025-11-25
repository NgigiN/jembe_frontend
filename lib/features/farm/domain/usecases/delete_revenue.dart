import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/revenue_repository.dart';

class DeleteRevenue implements UseCase<void, String> {
  final RevenueRepository repository;

  DeleteRevenue(this.repository);

  @override
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteRevenue(id);
  }
}


