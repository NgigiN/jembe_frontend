import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';
import 'package:farm_tracker/features/farm/domain/repositories/herd_activity_repository.dart';

class AddHerdActivity {
  AddHerdActivity(this.repository);
  final HerdActivityRepository repository;

  Future<Either<Failure, HerdActivity>> call(
    String herdId,
    String activityType,
    int count,
    DateTime date,
    String? notes,
  ) async {
    return repository.addHerdActivity(herdId, activityType, count, date, notes);
  }
}
