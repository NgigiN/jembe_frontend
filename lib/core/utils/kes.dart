/// Kenyan-shilling formatting for the web console (DESIGN_SPEC §7:
/// `KES 15,900`, never `KES 15900.00`).
///
/// Written out rather than pulled from `intl` because this is the only
/// formatting the console needs and the app has no `intl` dependency —
/// adding one for a thousands separator would be the larger change.
library;

/// `KES 15,900`. With [signed], carries an explicit leading sign the way
/// table amount cells do: `−KES 3,400` for an input, `+KES 12,600` for
/// revenue. The minus is U+2212, which lines up with digits in Fraunces;
/// ASCII `-` does not.
String formatKes(num amount, {bool signed = false}) {
  final rounded = amount.round();
  final magnitude = _groupDigits(rounded.abs());
  final sign = switch (rounded) {
    < 0 => '−',
    > 0 when signed => '+',
    _ => '',
  };
  return '${sign}KES $magnitude';
}

/// `15,900` — the same grouping without the currency, for chart axes and
/// anywhere the unit is already stated in a header.
String formatAmount(num amount) => _groupDigits(amount.round().abs());

String _groupDigits(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
