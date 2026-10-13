import 'dart:async';

import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:flutter/material.dart';

/// Where the farm owner renews the team plan from a browser.
///
/// Takes its data source as a constructor argument like the other console
/// pages, and fetches its own entitlement rather than reading a cubit: the
/// console has none, and re-fetching after a payment is all it needs.
class WebBillingPage extends StatefulWidget {
  const WebBillingPage({required this.remote, super.key});

  final BillingRemoteDataSource remote;

  @override
  State<WebBillingPage> createState() => _WebBillingPageState();
}

class _WebBillingPageState extends State<WebBillingPage> {
  /// How long Paystack gives the customer to enter their PIN.
  static const _pinWindowSeconds = 180;

  final _phone = TextEditingController();

  Entitlement? _ent;
  String? _loadError;

  int? _seats;
  int _months = 1;

  bool _paying = false; // guards the HTTP call (sub-second)
  int? _secondsLeft; // guards the PENDING payment (up to 180s)
  Timer? _countdown;
  Timer? _poll;

  // Captured BEFORE the charge. Success is a CHANGE against these, never an
  // absolute state: an owner renewing early is ALREADY active, so keying off
  // state == active would never confirm for them and they would wait the full
  // 180 seconds and then be told to try again.
  int? _seatsBefore;
  DateTime? _throughBefore;

  bool _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _poll?.cancel();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadEntitlement() async {
    if (mounted && _loadError != null) setState(() => _loadError = null);
    try {
      final next = await widget.remote.getEntitlement();
      if (!mounted) return;
      setState(() {
        _ent = next;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError = 'We could not load your plan. Reload the page.',
      );
    }
  }

  int get _collaborators => _ent?.collaborators ?? 0;
  int get _effectiveSeats =>
      _seats ?? (_collaborators < 1 ? 1 : _collaborators);

  int get _monthlyKes => _ent?.priceFor(_effectiveSeats) ?? 0;

  /// Twelve months cost ten. Charging twelve would overcharge; showing twelve
  /// would misprice the discount being advertised.
  int get _chargedKes =>
      _months == 12 ? _monthlyKes * 10 : _monthlyKes * _months;

  bool get _pending => (_secondsLeft ?? 0) > 0;

  Future<void> _pay() async {
    final phone = _phone.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter the M-Pesa number to charge.');
      return;
    }
    // Both guards matter and they cover different windows.
    if (_paying || _pending) return;

    setState(() {
      _paying = true;
      _error = null;
      _confirmed = false;
      _seatsBefore = _ent?.seatsPaid;
      _throughBefore = _ent?.paidThrough;
    });

    try {
      await widget.remote.checkout(
        seats: _effectiveSeats,
        months: _months,
        phone: phone,
      );
      if (!mounted) return;
      _startPendingWindow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // The server's own message is written for a farmer: a 409 says a push
        // is already waiting, a 402 says the plan does not cover the seats.
        // Showing it beats a generic failure, which would send them looking
        // for another way to pay.
        _error = e is ServerException && (e.message?.isNotEmpty ?? false)
            ? e.message
            : 'We could not reach M-Pesa. Check the number and try again.';
      });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// For the whole PIN window the payment is pending, so Pay stays disabled:
  /// the HTTP call finishing tells us nothing about whether money moved.
  void _startPendingWindow() {
    setState(() => _secondsLeft = _pinWindowSeconds);
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = (_secondsLeft ?? 1) - 1;
      setState(() => _secondsLeft = left);
      if (left <= 0) {
        t.cancel();
        _poll?.cancel();
      }
    });
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkForPayment(),
    );
  }

  Future<void> _checkForPayment() async {
    if (!mounted) return;
    try {
      final next = await widget.remote.getEntitlement();
      if (!mounted) return;
      final seatsRose = _seatsBefore != null && next.seatsPaid > _seatsBefore!;
      final windowMoved =
          next.paidThrough != null &&
          (_throughBefore == null ||
              next.paidThrough!.isAfter(_throughBefore!));
      setState(() => _ent = next);
      if (seatsRose || windowMoved) {
        _countdown?.cancel();
        _poll?.cancel();
        setState(() {
          _confirmed = true;
          _secondsLeft = null;
        });
      }
    } catch (_) {
      // A failed poll is not a failed payment. Say nothing and try again.
    }
  }

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// 1100 -> "1,100".
  String _kes(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // ConsolePage supplies the header, padding and scrolling but no Material,
    // which the text field and buttons below need.
    return Material(
      type: MaterialType.transparency,
      child: ConsolePage(
        title: 'Billing',
        subtitle: 'Your team plan and renewals',
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final ent = _ent;

    if (ent == null) {
      if (_loadError == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadEntitlement,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (!ent.isOwner) {
      return const Text(
        'Billing is managed by the farm owner, so only the farm owner can '
        'renew this plan.',
      );
    }

    if (_confirmed) {
      final through = ent.paidThrough;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment received. Your team can record work again.'),
          if (through != null) ...[
            const SizedBox(height: 8),
            Text('Paid through ${_date(through)}.'),
          ],
        ],
      );
    }

    final seats = _effectiveSeats;
    final secondsLeft = _secondsLeft;
    final expired = secondsLeft != null && secondsLeft <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your team plan', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Working with other people, managers or workers, is a monthly '
          'plan. Everyone you add can record work on your farms, and you can '
          'add or remove people whenever you like.',
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
                  onPressed: seats <= 1 || _pending
                      ? null
                      : () => setState(() => _seats = seats - 1),
                ),
                Text('$seats', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add a person',
                  onPressed: seats >= ent.seatCap || _pending
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
              'For a team larger than ${ent.seatCap}, get in touch and we '
              'will work something out.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const Divider(height: 32),
        Text(
          'KES ${_kes(_monthlyKes)} a month',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'KES ${_kes(ent.baseKes)} plus KES ${_kes(ent.perCollaboratorKes)} for each '
          'person.',
          style: theme.textTheme.bodySmall,
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
          onSelectionChanged: _pending
              ? null
              : (s) => setState(() => _months = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          _months == 12
              ? 'Pay KES ${_kes(_chargedKes)} for a year, two months free.'
              : 'Pay KES ${_kes(_chargedKes)} now.',
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
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_pending)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Check your phone and enter your M-Pesa PIN. Your team '
              'unlocks as soon as the payment goes through.\n'
              'You can try again in ${_clock(secondsLeft!)} if the prompt '
              'does not arrive.',
            ),
          ),
        if (expired)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'The prompt may not have arrived. Check the number and try '
              'again.',
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: (_paying || _pending) ? null : _pay,
            child: _paying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(expired ? 'Try again' : 'Pay with M-Pesa'),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'If a plan ever lapses nothing is deleted. Your team can still see '
          'everything, and you keep full access to your own farms.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
