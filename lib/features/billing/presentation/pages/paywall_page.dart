import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Explains the team plan. It does NOT sell it.
///
/// Renewal happens on the web console, deliberately. Google Play requires
/// digital purchases made inside a Play-distributed app to go through Play
/// Billing, and Kenya does not reach the external-billing liberalisation
/// until September 2027, so taking mobile money for app functionality in here
/// risks the listing itself, not a fee. A disabled button or a hidden form
/// would carry the same risk, which is why there is no payment affordance at
/// all rather than an inert one.
///
/// It also removes a double charge no server guard can close: with payment in
/// two clients a farmer can start a push on each, producing two references
/// that are both legitimate payments.
class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  static const _consoleHost = 'farmtracker.samtama.lol';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntitlementCubit, EntitlementStatus>(
      builder: (context, status) {
        final ent = status.entitlement;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(title: const Text('Your team plan')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Shamba is free for your own farms.',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Working with other people, managers or workers, is a '
                'monthly plan. Everyone you add can record work on your '
                'farms.',
              ),
              const Divider(height: 32),
              if (ent.isOwner)
                ..._ownerSection(theme, ent)
              else
                ..._memberSection(),
              const SizedBox(height: 24),
              Text(
                'If a plan lapses nothing is deleted. Your team can still see '
                'everything, and you keep full access to your own farms.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _ownerSection(ThemeData theme, Entitlement ent) {
    return [
      if (ent.priceKes > 0) ...[
        Text(
          'KES ${_thousands(ent.priceKes)} a month',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'KES ${_thousands(ent.baseKes)} plus KES '
          '${_thousands(ent.perCollaboratorKes)} for each person.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
      ],
      Text('Renew on the web', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text(
        'Open the Shamba console on a computer or in a browser and go to '
        'Billing. This app unlocks on its own once the renewal goes through.',
      ),
      const SizedBox(height: 12),
      SelectableText(_consoleHost, style: theme.textTheme.titleSmall),
    ];
  }

  List<Widget> _memberSection() {
    // A collaborator receives none of the billing detail, and cannot renew
    // somebody else's farm anyway. All they need is who to ask, so no price
    // is ever shown here: the zeros the parser fills in are not real prices.
    return const [
      Text(
        'This farm is read-only until its owner renews the team plan. '
        'Nothing has been lost, so please ask the farm owner to renew.',
      ),
    ];
  }

  static String _thousands(int n) {
    final digits = n.abs().toString();
    final out = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
