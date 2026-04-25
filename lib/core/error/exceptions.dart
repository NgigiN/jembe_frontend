import 'package:equatable/equatable.dart';

abstract class Exceptions extends Equatable {
  const Exceptions();

  @override
  List<Object?> get props => [];
}

class ServerException extends Exceptions {
  const ServerException([this.message]);
  final String? message;
  @override
  List<Object?> get props => [message];
}

class CacheException extends Exceptions {}

class NetworkException extends Exceptions {}
