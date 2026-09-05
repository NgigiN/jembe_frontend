import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/injection_container.dart' as di;
import 'package:farm_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    AppConfig.initialize();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Without a handler the secure-storage channel's future never resolves
    // in tests, hanging the async router redirect; null = "no stored value".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    await GetIt.instance.reset();
    await di.init();
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets(
    'router instance is stable across rebuilds (theme/state changes must '
    'not drop the nav stack)',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      final first =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig;

      // Force a full rebuild of the same MyApp element/state, mirroring
      // what a ThemeBloc emission does in production.
      await tester.pumpWidget(const MyApp());
      await tester.pump();
      final second =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig;

      expect(first, isA<GoRouter>());
      expect(
        identical(first, second),
        isTrue,
        reason:
            'a fresh GoRouter/AppRouter on every build drops the nav stack '
            'on any rebuild (e.g. a theme change)',
      );

      // Drain SplashPage's min-display timer and the AnalyticsService
      // flush timer that its app_open track() call started, so no Timer
      // is left pending at teardown (their removal is tracked separately).
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
    },
  );
}
