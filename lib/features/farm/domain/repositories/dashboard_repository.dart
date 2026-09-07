import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';

// ignore: one_member_abstracts
abstract class DashboardRepository {
  Future<Either<Failure, Dashboard>> getDashboard();
}
