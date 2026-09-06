import 'package:equatable/equatable.dart';

abstract class Exceptions extends Equatable implements Exception {
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

/// Thrown by a syncer's push when a child record's FK still points at a
/// parent that has not synced (no server id yet). It is NOT a failure: the
/// engine parks the entry (leaves it `pending`, no backoff) and retries it on
/// the next pass, after the parent has synced. Distinct from
/// `NetworkException` (transient, stops the phase) and `ServerException`
/// (permanent, parks as `failed`).
class SyncDependencyException extends Exceptions {}
