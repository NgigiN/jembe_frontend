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
  bool _refreshWanted = false;

  /// Fetches entitlement, replacing whatever is held. Dropped if a fetch is
  /// already running — the in-flight result is just as good, and three
  /// consumers mounting at once must not make three requests.
  Future<void> load() async {
    if (_inFlight) return;
    await _run(keepOnFailure: false);
  }

  /// Re-fetches, keeping the known value if the request fails. Called after a
  /// payment and on a farm switch.
  ///
  /// Unlike [load] this COALESCES rather than drops. A refresh means something
  /// has changed, so the currently in-flight response is already stale; the
  /// post-payment refresh in particular must not be thrown away, or a farmer
  /// who has just paid keeps seeing a lapsed farm.
  Future<void> refresh() async {
    if (_inFlight) {
      _refreshWanted = true;
      return;
    }
    await _run(keepOnFailure: true);
  }

  Future<void> _run({required bool keepOnFailure}) async {
    _inFlight = true;
    try {
      emit(state.copyWith(loading: true));
      final next = await remote.getEntitlement();
      emit(EntitlementStatus(entitlement: next, loading: false));
    } catch (e, st) {
      appLogger.logError('EntitlementCubit: fetch', e, st);
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
    if (_refreshWanted) {
      _refreshWanted = false;
      // Always keepOnFailure: a coalesced call must not discard what the
      // previous one just learned.
      await _run(keepOnFailure: true);
    }
  }
}
