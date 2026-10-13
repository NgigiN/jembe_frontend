import 'dart:async';

import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/presentation/cubit/entitlement_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The screen someone reaches when they try to add a teammate they are not
/// yet paying for.
///
/// This is the sales conversation, at the moment of highest intent. It leads
/// with what stays free, shows a computed number rather than a formula, and
/// never surfaces a raw server error.
class PaywallPage extends StatefulWidget {
  const PaywallPage({required this.remote, super.key});

  final BillingRemoteDataSource remote;

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  final _phone = TextEditingController();

  int? _seats;
  int _months = 1;
  bool _paying = false;
  String? _error;
  String? _sentTo;

  /// How long Paystack gives the customer to enter their PIN. Until it has
  /// passed the first push may still be approved, so a second charge could
  /// bill the same month twice.
  static const _pinWindowSeconds = 180;
  int? _secondsLeft;
  Timer? _countdown;

  bool get _pending => (_secondsLeft ?? 0) > 0;

  void _startCountdown() {
    _countdown?.cancel();
    _secondsLeft = _pinWindowSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft = (_secondsLeft ?? 1) - 1);
      if ((_secondsLeft ?? 0) <= 0) timer.cancel();
    });
  }

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _countdown?.cancel();
    _phone.dispose();
    super.dispose();
  }

  /// Starts from the team the farm already has — including the person they
  /// just tried to add — so the default is the number they actually need.
  int _initialSeats(int collaborators) => collaborators < 1 ? 1 : collaborators;

  Future<void> _pay(int seats) async {
    final phone = _phone.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter the M-Pesa number to charge.');
      return;
    }
    // Guards the double tap. Without it an impatient second press on a slow
    // connection starts a second charge, and the farmer pays twice.
    // The payment itself stays pending after the request returns, so a
    // running countdown blocks a second charge too.
    if (_paying || _pending) return;
    setState(() {
      _paying = true;
      _error = null;
      _sentTo = null;
    });
    try {
      await widget.remote.checkout(seats: seats, months: _months, phone: phone);
      if (!mounted) return;
      setState(() => _sentTo = phone);
      _startCountdown();
      // Entitlement changes only once the webhook lands, which is seconds
      // away at best. Refresh so the farm unlocks without a restart.
      await context.read<EntitlementCubit>().refresh();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'We could not reach M-Pesa. Check the number and try again.',
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntitlementCubit, EntitlementStatus>(
      builder: (context, status) {
        final ent = status.entitlement;
        final seats = _seats ?? _initialSeats(ent.collaborators);
        final monthly = ent.priceFor(seats);
        final charged = _months == 12 ? monthly * 10 : monthly * _months;

        return Scaffold(
          appBar: AppBar(title: const Text('Your team plan')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Shamba is free for your own farms.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Working with other people — managers or workers — is a '
                'monthly plan. Everyone you add can record work on your '
                'farms, and you can add or remove people whenever you like.',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('People on your team'),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Remove a person',
                        onPressed: seats <= 1
                            ? null
                            : () => setState(() => _seats = seats - 1),
                      ),
                      Text(
                        '$seats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Add a person',
                        onPressed: seats >= ent.seatCap
                            ? null
                            : () => setState(() => _seats = seats + 1),
                      ),
                    ],
                  ),
                ],
              ),
              if (seats >= ent.seatCap)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'For a team larger than ${ent.seatCap}, get in touch and '
                    'we will work something out.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Divider(height: 32),
              Text(
                'KES $monthly a month',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'KES ${ent.baseKes} plus KES ${ent.perCollaboratorKes} '
                'for each person.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1 month')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 6, label: Text('6')),
                  ButtonSegment(value: 12, label: Text('1 year')),
                ],
                selected: {_months},
                onSelectionChanged: (s) => setState(() => _months = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _months == 12
                    ? 'Pay KES $charged for a year — two months free.'
                    : 'Pay KES $charged now.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'M-Pesa number',
                  hintText: '07XX XXX XXX',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_sentTo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _pending
                        ? 'Check your phone and enter your M-Pesa PIN. This '
                              'usually takes a few seconds. Your team unlocks '
                              'as soon as the payment goes through.\n'
                              'You can try again in ${_clock(_secondsLeft!)} if '
                              'the prompt does not arrive.'
                        : 'Check your phone — enter your M-Pesa PIN to '
                              'finish. If no prompt arrived, you can try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (_paying || _pending) ? null : () => _pay(seats),
                child: _paying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_sentTo != null ? 'Try again' : 'Pay with M-Pesa'),
              ),
              const SizedBox(height: 24),
              Text(
                'If a plan ever lapses nothing is deleted. Your team can '
                'still see everything, and you keep full access to your own '
                'farms.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
