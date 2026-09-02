import 'dart:async';

import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/services.dart';

/// Centralizes the haptic+sound combination for each of the trigger
/// table's reward moments, so every call site is a single line instead of
/// duplicating HapticFeedback/SoundService calls ~30 times over.
class SuccessFeedback {
  const SuccessFeedback._();

  static void saved() {
    HapticFeedback.lightImpact();
    _playChimeIfAvailable();
  }

  static void deleted() {
    HapticFeedback.mediumImpact();
  }

  static void thriving() {
    HapticFeedback.mediumImpact();
    _playChimeIfAvailable();
  }

  static void _playChimeIfAvailable() {
    if (sl.isRegistered<SoundService>()) {
      unawaited(sl<SoundService>().playSuccess());
    }
  }
}
