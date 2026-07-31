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

class InvalidInputFailure extends Failure {
  const InvalidInputFailure() : super('Invalid input provided');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Unauthorized access. Please log in again.');
}

String resolveFailureMessage(Failure failure, String fallback) {
  if (failure is NetworkFailure) {
    return 'No internet connection. Check your network and try again.';
  }
  if (failure is ServerFailure && failure.errorMessage != null) {
    return failure.errorMessage!;
  }
  return fallback;
}
