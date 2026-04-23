abstract class Failure {
  final String message;
  const Failure([this.message = 'An unexpected error occurred']);
}

class ServerFailure extends Failure {
  final String? errorMessage;
  const ServerFailure([this.errorMessage]) : super(errorMessage ?? 'Server error occurred');
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
