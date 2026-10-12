import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:farm_tracker/features/billing/presentation/widgets/maybe_entitlement_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A persistent notice for a collaborator whose farm's plan has lapsed.
///
/// Deliberately not shown to the owner. A lapse drops the farm back to what a
/// free account gets — one working user — and that user is the owner. What
/// they lose is the thing they stopped paying for and nothing else.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  /// Builds the banner for an entitlement directly, without a cubit. Used by
  /// tests and by anywhere that already holds the value.
  static Widget forEntitlement(Entitlement entitlement) {
    return _Banner(entitlement: entitlement);
  }

  /// Whether this viewer should see it: a lapsed plan, and not the owner.
  static bool appliesTo(Entitlement entitlement) {
    return entitlement.isLapsed && !entitlement.isOwner;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = maybeEntitlementCubit(context);
    // No cubit means the entitlement is unknown; show nothing.
    if (cubit == null) return const SizedBox.shrink();
    return BlocBuilder<EntitlementCubit, EntitlementStatus>(
      bloc: cubit,
      builder: (context, status) => _Banner(entitlement: status.entitlement),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    if (!ReadOnlyBanner.appliesTo(entitlement)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: scheme.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 20,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This farm is read-only until the owner renews the team plan. '
              'You can still see everything — nothing has been lost.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
