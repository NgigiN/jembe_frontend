import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activity_repository.dart';

class GetActivities implements UseCase<List<Activity>, NoParams> {
  final ActivityRepository repository;

  GetActivities(this.repository);

  @override
  Future<Either<Failure, List<Activity>>> call(NoParams params) async {
    return await repository.getActivities();
  }
}
