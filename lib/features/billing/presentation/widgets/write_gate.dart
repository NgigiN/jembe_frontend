import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:farm_tracker/features/billing/presentation/widgets/maybe_entitlement_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reports whether the viewer may write in the current farm, so a caller can
/// disable its own affordances.
///
/// Why this is client-side, which looks like the wrong place for an
/// entitlement check: the app is offline-first, and a write goes into a local
/// outbox before it ever reaches the server. The sync engine treats any
/// ServerException on push as PERMANENT — it marks the row failed, and
/// nothing in this app retries, surfaces or counts a failed row. So a server
/// that refused writes with a 402 would silently destroy every queued entry
/// on every device the moment a plan lapsed.
///
/// The server therefore never refuses a write on billing grounds, and the
/// app's job is to not offer one. Disable the button; never let the write
/// start and fail.
class WriteGate extends StatelessWidget {
  const WriteGate({required this.builder, super.key});

  // ignore: avoid_positional_boolean_parameters
  final Widget Function(BuildContext context, bool allowed) builder;

  /// Writing is allowed unless this is a collaborator on a lapsed plan.
  ///
  /// Reads `canWrite`, which the server already computes with the owner
  /// exemption applied, and defaults to true for anything unknown.
  // ignore: avoid_positional_boolean_parameters
  static bool allows(Entitlement entitlement) {
    return entitlement.isOwner || entitlement.canWrite;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = maybeEntitlementCubit(context);
    // No cubit means the entitlement is unknown, and unknown falls open.
    if (cubit == null) return builder(context, true);
    return BlocBuilder<EntitlementCubit, EntitlementStatus>(
      bloc: cubit,
      builder: (context, status) =>
          builder(context, allows(status.entitlement)),
    );
  }
}
