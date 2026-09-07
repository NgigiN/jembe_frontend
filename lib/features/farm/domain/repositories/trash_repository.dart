import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';

abstract class TrashRepository {
  Future<Either<Failure, List<TrashItem>>> getTrash();
  Future<Either<Failure, void>> restore({
    required String entity,
    required String id,
  });
}
