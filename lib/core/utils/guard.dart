import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';

/// Runs [body] and maps its outcome to an `Either<Failure, T>`, collapsing the
/// repository flag-off (live-HTTP) try/catch boilerplate (audit R2-02) into a
/// single call.
///
/// Mapping — identical to the hand-written branches it replaces:
/// - success                -> `Right(result)`
/// - [NetworkException]     -> `Left(NetworkFailure())`
/// - [UnauthorizedException] -> `Left(UnauthorizedFailure())` (F1-05/S4-C1)
/// - [ServerException]      -> `Left(ServerFailure(e.message))`
///
/// By default any OTHER error is rethrown, matching the repositories that only
/// ever carried the two `on ...Exception` catches — their behaviour stays
/// byte-for-byte the same. The repositories that additionally had a generic
/// `catch (e) => ServerFailure(...)` fallback (F1-08 finding #8: `animal_type`,
/// `herd`, `herd_activity` and `infrastructure` used `'Unexpected error: $e'`;
/// `cost_category` used `e.toString()`) opt back into that exact fallback by
/// passing [onUnexpected] — guard then returns `ServerFailure(onUnexpected(e))`
/// for an unexpected error instead of rethrowing, preserving each repo's
/// original message.
Future<Either<Failure, T>> guard<T>(
  Future<T> Function() body, {
  String Function(Object error)? onUnexpected,
}) async {
  try {
    return Right(await body());
  } on NetworkException {
    return const Left(NetworkFailure());
  } on UnauthorizedException {
    return const Left(UnauthorizedFailure());
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  } catch (e) {
    if (onUnexpected == null) rethrow;
    return Left(ServerFailure(onUnexpected(e)));
  }
}
