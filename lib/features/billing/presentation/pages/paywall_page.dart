import 'dart:async';

import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
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

  /// How often entitlement is re-read while the payment is pending. The
  /// webhook that grants the seat lands seconds after the PIN is entered.
  static const _pollInterval = Duration(seconds: 3);
  Timer? _poller;

  /// What was true before the charge, to tell whether the payment landed.
  int _seatsBefore = 0;
  DateTime? _paidThroughBefore;

  /// Set once the payment has been seen to land. The transaction is done.
  Entitlement? _paid;

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
      if ((_secondsLeft ?? 0) <= 0) {
        timer.cancel();
        _poller?.cancel();
      }
    });
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted || _paid != null) return;
    final cubit = context.read<EntitlementCubit>();
    await cubit.refresh();
    if (!mounted || _paid != null) return;
    _checkLanded(cubit.state.entitlement);
  }

  /// Compares against the pre-charge values rather than the billing state:
  /// an account renewing early is already active, so its state never moves.
  void _checkLanded(Entitlement now) {
    final through = now.paidThrough;
    final prior = _paidThroughBefore;
    final moved = through != null && (prior == null || through.isAfter(prior));
    if (now.seatsPaid > _seatsBefore || moved) {
      _countdown?.cancel();
      _poller?.cancel();
      setState(() {
        _paid = now;
        _secondsLeft = 0;
      });
    }
  }

  String _day(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _countdown?.cancel();
    _poller?.cancel();
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
    final before = context.read<EntitlementCubit>().state.entitlement;
    _seatsBefore = before.seatsPaid;
    _paidThroughBefore = before.paidThrough;
    setState(() {
      _paying = true;
      _error = null;
      _sentTo = null;
    });
    try {
      await widget.remote.checkout(seats: seats, months: _months, phone: phone);
      if (!mounted) return;
      setState(() => _sentTo = phone);
      // Entitlement changes only once the webhook lands, seconds from now,
      // so an immediate refresh would read the old value. Poll instead.
      _startCountdown();
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
              if (_paid != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _paid!.paidThrough == null
                        ? 'Payment received. Your team can record work again.'
                        : 'Payment received. Your team can record work '
                              'again.\nPaid through '
                              '${_day(_paid!.paidThrough!)}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else if (_sentTo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _pending
                        ? 'Check your phone and enter your M-Pesa PIN. This '
                              'usually takes a few seconds. Your team unlocks '
                              'as soon as the payment goes through.\n'
                              'You can try again in ${_clock(_secondsLeft!)} if '
                              'the prompt does not arrive.'
                        : 'The M-Pesa prompt may not have arrived. If your '
                              'phone showed nothing, you can try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 16),
              if (_paid == null)
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
