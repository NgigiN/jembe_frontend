import 'package:farm_tracker/features/farm_activity/domain/farm_activity_calculator.dart';
import 'package:flutter/material.dart';

/// Icon/color/label/explanation mapping shared by every place that shows a
/// [FarmActivityLevel] to the user, so the card and the streak detail page
/// never drift apart.
IconData farmActivityIconFor(FarmActivityLevel level) => switch (level) {
  FarmActivityLevel.thriving => Icons.eco,
  FarmActivityLevel.onTrack => Icons.trending_up,
  FarmActivityLevel.needsAttention => Icons.warning_amber,
};

Color farmActivityColorFor(FarmActivityLevel level) => switch (level) {
  FarmActivityLevel.thriving => Colors.green,
  FarmActivityLevel.onTrack => Colors.orange,
  FarmActivityLevel.needsAttention => Colors.red,
};

String farmActivityLabelFor(FarmActivityLevel level) => switch (level) {
  FarmActivityLevel.thriving => 'Thriving',
  FarmActivityLevel.onTrack => 'On track',
  FarmActivityLevel.needsAttention => 'Needs attention',
};

String farmActivityExplanationFor(FarmActivityLevel level) => switch (level) {
  FarmActivityLevel.thriving =>
    'Your herds and seasons all have recent activity logged. Keep it up!',
  FarmActivityLevel.onTrack =>
    'Most of your herds and seasons have recent activity, but a few could '
        'use an update.',
  FarmActivityLevel.needsAttention =>
    "Several of your herds and seasons haven't had any activity, input, or "
        'harvest logged recently.',
};
