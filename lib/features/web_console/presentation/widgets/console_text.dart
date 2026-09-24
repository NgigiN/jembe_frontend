import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/utils/kes.dart';
import 'package:flutter/material.dart';

/// An 11px uppercase section label — "FARM", "COST BREAKDOWN", "SEASON"
/// (DESIGN_SPEC §1). Uppercases its own text so callers write it the way
/// they'd say it.
class ConsoleKicker extends StatelessWidget {
  const ConsoleKicker(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.kicker.copyWith(color: color ?? context.console.muted),
    );
  }
}

/// How a money amount is coloured, which in the console is a statement
/// about what the number *is* rather than a free choice of colour.
enum MoneyTone {
  /// Plain `onSurface` — a cost, a total, anything neutral.
  neutral,

  /// `statusPositive` — revenue, and profit that came out above zero.
  positive,

  /// `statusNegative` — profit that came out below zero.
  negative,

  /// `muted` — a zero in an empty state.
  muted,

  /// Coloured by the amount's own sign: negative reads negative, anything
  /// else reads neutral. What a profit row wants.
  bySign,
}

/// A KES amount in Fraunces with tabular figures (DESIGN_SPEC §1, §3).
///
/// Every amount in the console goes through here: the tabular figures are
/// what keep a column of shillings aligned, and routing the colour through
/// [MoneyTone] is what stops "negative profit is red" from being
/// re-decided in each table.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    this.size = 15,
    this.tone = MoneyTone.neutral,
    this.signed = false,
    this.placeholder,
    super.key,
  });

  /// Renders the spec's em-dash placeholder for a row with no amount.
  const MoneyText.none({double size = 15, Key? key})
    : this(null, size: size, placeholder: '—', key: key);

  final num? amount;
  final double size;
  final MoneyTone tone;

  /// Carries an explicit `+` / `−`, the way table amount cells do.
  final bool signed;

  /// Shown instead when [amount] is null. Defaults to an em dash.
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.amount(size);
    if (amount == null) {
      return Text(
        placeholder ?? '—',
        style: style.copyWith(color: context.console.muted),
      );
    }
    return Text(
      formatKes(amount!, signed: signed),
      style: style.copyWith(color: _color(context)),
    );
  }

  Color _color(BuildContext context) {
    final status = context.statusColors;
    return switch (tone) {
      MoneyTone.neutral => Theme.of(context).colorScheme.onSurface,
      MoneyTone.positive => status.positive,
      MoneyTone.negative => status.negative,
      MoneyTone.muted => context.console.muted,
      MoneyTone.bySign => (amount ?? 0) < 0
          ? status.negative
          : Theme.of(context).colorScheme.onSurface,
    };
  }
}
