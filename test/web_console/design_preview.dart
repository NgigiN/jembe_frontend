// Renders console screens to PNGs under build/design-preview/ so the
// layout can be checked against the reference screens in
// `docs/UI mockups brand decision/handoff/` without a running backend.
//
// This is a harness, not a test: it asserts nothing and guards nothing. It
// exists because "matches the mockup" is a claim you can only make by
// looking, and the alternative — sign in against a live server and
// screenshot the browser — needs real data for states (empty, error,
// worker) that real data will not reliably produce.
//
// Run: flutter test test/web_console/design_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const previewDirectory = 'build/design-preview';

/// The mockups' own sample farm (DESIGN_SPEC §8), so a preview can be laid
/// beside the reference screen and compared row for row.
const sampleUserName = 'Kamau Owner';
const sampleUserEmail = 'kamau@gmail.com';
const sampleFarmName = 'Keringet';

/// Loads the app's real fonts into the test binding. Without this every
/// preview renders in the test runner's fallback font, and the type ramp —
/// the thing most worth checking — is exactly what you cannot see.
Future<void> loadConsoleFonts() async {
  const families = {
    'Fraunces': 'assets/fonts/Fraunces-var.ttf',
    'WorkSans': 'assets/fonts/WorkSans-var.ttf',
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }

  // The test runner starts with --disable-asset-fonts, so Material's icon
  // font is absent too and every icon renders as an empty box. Loading it
  // back is the difference between checking a layout and checking a screen.
  try {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  } on Object {
    // Previews stay useful without it; boxes where icons should be are a
    // recognisable, harmless artefact.
  }
}

/// Wraps [page] in the console's theme and sidebar, at the mockups' own
/// 1280px width.
Widget previewShell(
  Widget page, {
  required String location,
  Brightness brightness = Brightness.light,
  ConsoleSidebarProps sidebar = const ConsoleSidebarProps(),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark
        ? WebConsoleTheme.dark()
        : WebConsoleTheme.light(),
    home: Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleSidebar(
            location: location,
            role: sidebar.role,
            farmName: sidebar.farmName,
            userName: sidebar.userName,
            userEmail: sidebar.userEmail,
            onNavigate: (_) {},
            onSignOut: () {},
            onSwitchFarm: () {},
          ),
          Expanded(child: page),
        ],
      ),
    ),
  );
}

/// The handful of sidebar inputs a preview varies (the worker screen, an
/// unloaded farm), defaulted to §8's sample owner.
class ConsoleSidebarProps {
  const ConsoleSidebarProps({
    this.role = FarmRole.owner,
    this.farmName = sampleFarmName,
    this.userName = sampleUserName,
    this.userEmail = sampleUserEmail,
  });

  final FarmRole? role;
  final String? farmName;
  final String userName;
  final String userEmail;
}

/// Pumps [app] at [size] and writes a PNG to `build/design-preview/<name>`.
Future<void> capture(
  WidgetTester tester,
  Widget app,
  String name, {
  Size size = const Size(1280, 900),
}) async {
  // Shadows are switched off in tests by default, and the console's one
  // hairline shadow is part of what a card looks like. Restored by hand at
  // the end of this function rather than via addTearDown: the framework
  // asserts the painting debug flags are back to their defaults before
  // teardown callbacks get a turn.
  debugDisableShadows = false;

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: app));
  // Fixed pumps rather than pumpAndSettle: a preview only needs the frame
  // the screen looks like, and anything that animates forever — a pulsing
  // skeleton, an indeterminate progress bar — makes pumpAndSettle spin
  // until its ten-minute timeout.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // A layout exception paints nothing rather than the red error box, so an
  // all-background capture is the failure mode this guards against.
  final exception = tester.takeException();
  if (exception != null) {
    throw StateError('$name did not render: $exception');
  }

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // Inside runAsync: PNG encoding is real async work on a background
  // thread, and the test binding's fake clock never completes it. Without
  // this the first capture in a file happens to succeed and every one
  // after it hangs until the suite times out.
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final directory = Directory(previewDirectory);
    if (!directory.existsSync()) directory.createSync(recursive: true);
    File('$previewDirectory/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  debugDisableShadows = true;
}
