import 'package:equatable/equatable.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EntitlementStatus extends Equatable {
  const EntitlementStatus({required this.entitlement, required this.loading});

  final Entitlement entitlement;
  final bool loading;

  EntitlementStatus copyWith({Entitlement? entitlement, bool? loading}) {
    return EntitlementStatus(
      entitlement: entitlement ?? this.entitlement,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [entitlement, loading];
}

/// Publishes the current farm's entitlement.
///
/// It has no error state on purpose. Every failure resolves to "keep what we
/// had, or be permissive" — because this value only ever decides whether the
/// app OFFERS a write, and being wrong in the restrictive direction costs a
/// paying farmer their afternoon's records while being wrong in the
/// permissive direction costs nothing but an unpaid seat.
class EntitlementCubit extends Cubit<EntitlementStatus> {
  EntitlementCubit({required this.remote})
    : super(
        const EntitlementStatus(
          entitlement: Entitlement.permissive(),
          loading: false,
        ),
      );

  final BillingRemoteDataSource remote;

  bool _inFlight = false;

  /// Fetches entitlement, replacing whatever is held.
  Future<void> load() => _fetch(keepOnFailure: false);

  /// Re-fetches, keeping the known value if the request fails. Called after
  /// a payment and on a farm switch.
  Future<void> refresh() => _fetch(keepOnFailure: true);

  Future<void> _fetch({required bool keepOnFailure}) async {
    // Not re-entrant: the gate is read by several widgets at once, and
    // without this a page with three consumers would fire three requests.
    if (_inFlight) return;
    _inFlight = true;
    emit(state.copyWith(loading: true));
    try {
      final next = await remote.getEntitlement();
      emit(EntitlementStatus(entitlement: next, loading: false));
    } catch (e, st) {
      appLogger.logError('EntitlementCubit: load', e, st);
      emit(
        EntitlementStatus(
          entitlement: keepOnFailure
              ? state.entitlement
              : const Entitlement.permissive(),
          loading: false,
        ),
      );
    } finally {
      _inFlight = false;
    }
  }
}
