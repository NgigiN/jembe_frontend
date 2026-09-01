import 'package:farm_tracker/core/audio/sound_service.dart';
import 'package:farm_tracker/core/feedback/success_feedback.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSoundPlayer implements SoundPlayer {
  final calls = <String>[];

  @override
  Future<void> play(String assetPath) async => calls.add(assetPath);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platformCalls = <MethodCall>[];

  setUp(() {
    platformCalls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    if (sl.isRegistered<SoundService>()) sl.unregister<SoundService>();
  });

  Iterable<MethodCall> hapticCalls() =>
      platformCalls.where((c) => c.method == 'HapticFeedback.vibrate');

  group('saved', () {
    test(
      'fires a light haptic and plays the sound when SoundService is registered',
      () async {
        final player = _FakeSoundPlayer();
        sl.registerLazySingleton<SoundService>(
          () => SoundService(player: player),
        );

        SuccessFeedback.saved();
        await pumpEventQueue();

        expect(hapticCalls(), hasLength(1));
        expect(
          hapticCalls().single.arguments,
          'HapticFeedbackType.lightImpact',
        );
        expect(player.calls, ['sounds/success.mp3']);
      },
    );

    test('still fires the haptic when SoundService is not registered', () {
      SuccessFeedback.saved();

      expect(hapticCalls(), hasLength(1));
      expect(hapticCalls().single.arguments, 'HapticFeedbackType.lightImpact');
    });
  });

  group('deleted', () {
    test('fires a medium haptic and never touches SoundService', () {
      SuccessFeedback.deleted();

      expect(hapticCalls(), hasLength(1));
      expect(
        hapticCalls().single.arguments,
        'HapticFeedbackType.mediumImpact',
      );
    });
  });

  group('thriving', () {
    test(
      'fires a medium haptic and plays the sound when SoundService is registered',
      () async {
        final player = _FakeSoundPlayer();
        sl.registerLazySingleton<SoundService>(
          () => SoundService(player: player),
        );

        SuccessFeedback.thriving();
        await pumpEventQueue();

        expect(hapticCalls(), hasLength(1));
        expect(
          hapticCalls().single.arguments,
          'HapticFeedbackType.mediumImpact',
        );
        expect(player.calls, ['sounds/success.mp3']);
      },
    );
  });
}
