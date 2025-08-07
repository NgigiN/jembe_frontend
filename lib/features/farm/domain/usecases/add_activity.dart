import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/activity.dart';
import '../repositories/activity_repository.dart';

class AddActivity implements UseCase<Activity, AddActivityParams> {
  final ActivityRepository repository;

  AddActivity(this.repository);

  @override
  Future<Either<Failure, Activity>> call(AddActivityParams params) async {
    return await repository.addActivity(params.activity);
  }
}

class AddActivityParams {
  final Activity activity;

  AddActivityParams({required this.activity});
}
