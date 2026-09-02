import 'package:audioplayers/audioplayers.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

const soundEffectsPrefsKey = 'sound_effects_enabled';

/// Thin seam over [AudioPlayer] so tests can substitute a fake without
/// touching the real audioplayers platform channel.
abstract class SoundPlayer {
  Future<void> play(String assetPath);
}

class AudioplayersSoundPlayer implements SoundPlayer {
  AudioplayersSoundPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String assetPath) => _player.play(AssetSource(assetPath));
}

class SoundService {
  SoundService({SoundPlayer? player})
    : _player = player ?? AudioplayersSoundPlayer();

  final SoundPlayer _player;

  Future<void> playSuccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(soundEffectsPrefsKey) ?? true;
      if (!enabled) return;
      await _player.play('sounds/success.mp3');
    } catch (e) {
      appLogger.warning(LogCategory.general, 'Sound playback failed', e);
    }
  }
}
