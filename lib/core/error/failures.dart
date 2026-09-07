abstract class Failure {
  const Failure([this.message = 'An unexpected error occurred']);
  final String message;
}

class ServerFailure extends Failure {
  const ServerFailure([this.errorMessage]) : super(errorMessage ?? 'Server error occurred');
  final String? errorMessage;
}

class CacheFailure extends Failure {
  const CacheFailure() : super('Cache error occurred');
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Unauthorized access. Please log in again.');
}

/// A 409 response (Phase 8 B2's trash restore: a still-tombstoned parent, or
/// a cost_category name/type/category collision). Kept distinct from
/// [ServerFailure] so callers can branch on conflict specifically (e.g. keep
/// the item in a trash list instead of removing it) while still getting the
/// backend's client-safe message surfaced via [resolveFailureMessage].
class ConflictFailure extends Failure {
  const ConflictFailure([this.errorMessage]) : super(errorMessage ?? 'Conflict');
  final String? errorMessage;
}

String resolveFailureMessage(Failure failure, String fallback) {
  if (failure is NetworkFailure) {
    return 'No internet connection. Check your network and try again.';
  }
  if (failure is UnauthorizedFailure) {
    return failure.message;
  }
  if (failure is ConflictFailure) {
    return failure.errorMessage ?? fallback;
  }
  if (failure is ServerFailure && failure.errorMessage != null) {
    return failure.errorMessage!;
  }
  return fallback;
}
