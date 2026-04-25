import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/activity_repository.dart';

class AddActivity implements UseCase<Activity, AddActivityParams> {
  AddActivity(this.repository);
  final ActivityRepository repository;

  @override
  Future<Either<Failure, Activity>> call(AddActivityParams params) async {
    return repository.addActivity(params.activity);
  }
}

class AddActivityParams {
  AddActivityParams({required this.activity});
  final Activity activity;
}
