abstract class Failure {}

class ServerFailure extends Failure {
  final String? errorMessage;
  ServerFailure([this.errorMessage]);
}

class CacheFailure extends Failure {}

class NetworkFailure extends Failure {}

class InvalidInputFailure extends Failure {}

class UnauthorizedFailure extends Failure {}
