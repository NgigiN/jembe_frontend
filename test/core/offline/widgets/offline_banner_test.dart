import 'dart:async';

import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/offline/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late MockConnectivityService connectivityService;
  late StreamController<bool> onlineController;

  setUp(() {
    connectivityService = MockConnectivityService();
    onlineController = StreamController<bool>.broadcast();
    when(
      () => connectivityService.onlineChanges,
    ).thenAnswer((_) => onlineController.stream);
  });

  tearDown(() async {
    OfflineConfig.enabled = false;
    await onlineController.close();
  });

  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: OfflineBanner(connectivityService: connectivityService),
      ),
    );
  }

  testWidgets('flag ON + offline stream ⇒ banner is visible', (tester) async {
    OfflineConfig.enabled = true;
    await tester.pumpWidget(harness());
    await tester.pump();

    onlineController.add(false);
    await tester.pump();
    await tester.pump();

    expect(
      find.text("You're offline — changes will sync when you reconnect"),
      findsOneWidget,
    );
  });

  testWidgets('flag ON + online ⇒ banner is hidden', (tester) async {
    OfflineConfig.enabled = true;
    await tester.pumpWidget(harness());
    await tester.pump();

    onlineController.add(true);
    await tester.pump();
    await tester.pump();

    expect(
      find.text("You're offline — changes will sync when you reconnect"),
      findsNothing,
    );
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('flag OFF ⇒ SizedBox.shrink() regardless of connectivity', (
    tester,
  ) async {
    OfflineConfig.enabled = false;
    await tester.pumpWidget(harness());
    await tester.pump();

    onlineController.add(false);
    await tester.pump();

    expect(
      find.text("You're offline — changes will sync when you reconnect"),
      findsNothing,
    );
    final sizedBox = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 0 && widget.height == 0,
      ),
    );
    expect(sizedBox.width, 0);
    expect(sizedBox.height, 0);

    // Never touches the injected service when the flag is off, so no
    // stream subscription is ever built.
    verifyNever(() => connectivityService.onlineChanges);
  });
}
