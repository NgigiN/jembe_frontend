import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/land.dart';

abstract class LandRepository {
  Future<Either<Failure, List<Land>>> getLands();
  Future<Either<Failure, Land>> addLand(Land land);
  Future<Either<Failure, Land>> updateLand(Land land);
  Future<Either<Failure, void>> deleteLand(String id);
}
