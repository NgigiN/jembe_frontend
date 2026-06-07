import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd_activity.dart';

abstract class HerdActivityRepository {
  Future<Either<Failure, HerdActivity>> addHerdActivity(
    String herdId,
    String activityType,
    int count,
    DateTime date,
    String? notes,
  );
}
