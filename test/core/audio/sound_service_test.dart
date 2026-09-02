import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSoundPlayer implements SoundPlayer {
  final calls = <String>[];
  bool shouldThrow = false;

  @override
  Future<void> play(String assetPath) async {
    if (shouldThrow) throw Exception('boom');
    calls.add(assetPath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSoundPlayer player;
  late SoundService service;

  setUp(() {
    player = _FakeSoundPlayer();
    service = SoundService(player: player);
  });

  test('plays the success asset when the toggle is unset (defaults on)', () async {
    SharedPreferences.setMockInitialValues({});
    await service.playSuccess();
    expect(player.calls, ['sounds/success.mp3']);
  });

  test('plays the success asset when the toggle is explicitly on', () async {
    SharedPreferences.setMockInitialValues({soundEffectsPrefsKey: true});
    await service.playSuccess();
    expect(player.calls, ['sounds/success.mp3']);
  });

  test('does not play when the toggle is off', () async {
    SharedPreferences.setMockInitialValues({soundEffectsPrefsKey: false});
    await service.playSuccess();
    expect(player.calls, isEmpty);
  });

  test('swallows player errors without throwing', () async {
    SharedPreferences.setMockInitialValues({});
    player.shouldThrow = true;
    await expectLater(service.playSuccess(), completes);
    expect(player.calls, isEmpty);
  });
}
