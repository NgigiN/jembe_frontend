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

class NetworkException extends Exceptions {}

/// Thrown by [mapDioException] (core/network/dio_client.dart) for a 401
/// response. Distinct from [ServerException] so the repository layer can
/// map it to `UnauthorizedFailure` instead of a generic `ServerFailure`
/// (F1-05/S4-C1). The 401 also independently triggers a forced logout via
/// the Dio error interceptor + `SessionExpiryNotifier` — this exception only
/// carries the failure signal back to whichever screen made the call.
class UnauthorizedException extends Exceptions {}

/// Thrown by a syncer's push when a child record's FK still points at a
/// parent that has not synced (no server id yet). It is NOT a failure: the
/// engine parks the entry (leaves it `pending`, no backoff) and retries it on
/// the next pass, after the parent has synced. Distinct from
/// `NetworkException` (transient, stops the phase) and `ServerException`
/// (permanent, parks as `failed`).
class SyncDependencyException extends Exceptions {}

/// Thrown by `TrashRemoteDataSourceImpl.restore` for a 409 response — a
/// restore blocked by a still-tombstoned parent, or (cost_category) a live
/// row colliding on the name/type/category partial-unique index (Phase 8
/// A3/B2). Distinct from [ServerException] so `TrashRepositoryImpl` can
/// surface it as a `ConflictFailure` instead of a generic one, mirroring how
/// [UnauthorizedException] is split out from [ServerException] for 401.
/// Scoped to the trash restore flow — `mapDioException`
/// (core/network/dio_client.dart), used by every other datasource, is not
/// touched, so no other endpoint's 409 handling changes.
class ConflictException extends ServerException {
  const ConflictException([super.message]);
}
