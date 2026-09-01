import 'package:flutter/material.dart';

@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.positive,
    required this.warning,
    required this.negative,
  });

  final Color positive;
  final Color warning;
  final Color negative;

  @override
  StatusColors copyWith({Color? positive, Color? warning, Color? negative}) {
    return StatusColors(
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      negative: negative ?? this.negative,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

extension StatusColorsX on BuildContext {
  /// Falls back to plain colorScheme roles when no [StatusColors] is
  /// registered - always true in the real app (AppTheme always registers
  /// one), but most widget tests build a bare MaterialApp with no theme at
  /// all, and this must degrade gracefully there rather than crash.
  StatusColors get statusColors {
    final theme = Theme.of(this);
    return theme.extension<StatusColors>() ??
        StatusColors(
          positive: theme.colorScheme.primary,
          warning: theme.colorScheme.tertiary,
          negative: theme.colorScheme.error,
        );
  }
}
