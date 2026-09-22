// lib/main_web.dart
//
// Web console entry point (spec §3) — separate from lib/main.dart (mobile).
// Never imports lib/injection_container.dart.
import 'package:farm_tracker/core/config/app_config.dart';
import 'package:farm_tracker/web_injection_container.dart' as web_di;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize();

  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) {
      AppConfig.appVersion = info.version;
    }
  } catch (_) {
    // Keep the "0.0.0" default; startup must never fail on version lookup —
    // same reasoning as lib/main.dart's identical try/catch.
  }

  await web_di.initWebDependencies();

  runApp(const _WebConsoleApp());
}

class _WebConsoleApp extends StatelessWidget {
  const _WebConsoleApp();

  @override
  Widget build(BuildContext context) {
    // Placeholder home — Task 7 replaces this with the real GoRouter +
    // WebAppRouter, Task 8 with WebConsoleShell.
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('web console'))),
    );
  }
}
