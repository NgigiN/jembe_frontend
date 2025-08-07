import 'package:equatable/equatable.dart';

abstract class Exceptions extends Equatable {
  const Exceptions([List properties = const <dynamic>[]]);

  @override
  List<Object?> get props => [];
}

class ServerException extends Exceptions {
  final String? message;
  const ServerException([this.message]);
  @override
  List<Object?> get props => [message];
}

class CacheException extends Exceptions {}

class NetworkException extends Exceptions {}
