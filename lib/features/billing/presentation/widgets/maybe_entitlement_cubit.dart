import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Looks up the [EntitlementCubit] above [context], or null if none is
/// provided.
///
/// A missing cubit means the entitlement is unknown (an entry point that has
/// not wired billing), and unknown must never degrade the app: callers fall
/// open, the same direction a failed entitlement request already falls.
EntitlementCubit? maybeEntitlementCubit(BuildContext context) {
  try {
    return context.read<EntitlementCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}
