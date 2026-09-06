import 'dart:async';

import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/offline/widgets/sync_status_indicator.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late MockSyncEngine syncEngine;
  late StreamController<SyncStatus> statusController;
  final fixedNow = DateTime(2026, 9, 5, 12);

  setUp(() {
    syncEngine = MockSyncEngine();
    statusController = StreamController<SyncStatus>.broadcast();
    when(
      () => syncEngine.statusStream,
    ).thenAnswer((_) => statusController.stream);
    when(
      () => syncEngine.status,
    ).thenReturn(const SyncStatus(phase: SyncPhase.idle));
    when(() => syncEngine.syncNow()).thenAnswer((_) async {});
  });

  tearDown(() async {
    OfflineConfig.enabled = false;
    await statusController.close();
  });

  Widget harness() {
    return MaterialApp(
      home: Scaffold(
        body: SyncStatusIndicator(syncEngine: syncEngine, now: () => fixedNow),
      ),
    );
  }

  testWidgets('flag ON + syncing ⇒ shows "Syncing…"', (tester) async {
    OfflineConfig.enabled = true;
    await tester.pumpWidget(harness());
    await tester.pump();

    statusController.add(const SyncStatus(phase: SyncPhase.syncing));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Syncing'), findsOneWidget);
  });

  testWidgets(
    'flag ON + idle with lastSyncedAt ⇒ shows relative "Synced ... ago"',
    (tester) async {
      OfflineConfig.enabled = true;
      await tester.pumpWidget(harness());
      await tester.pump();

      statusController.add(
        SyncStatus(
          phase: SyncPhase.idle,
          lastSyncedAt: fixedNow.subtract(const Duration(minutes: 5)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Synced 5m ago'), findsOneWidget);
    },
  );

  testWidgets('flag ON + idle with pendingCount ⇒ shows "N pending"', (
    tester,
  ) async {
    OfflineConfig.enabled = true;
    await tester.pumpWidget(harness());
    await tester.pump();

    statusController.add(
      const SyncStatus(phase: SyncPhase.idle, pendingCount: 3),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('3 pending'), findsOneWidget);
  });

  testWidgets('flag ON + error ⇒ shows "Sync error"', (tester) async {
    OfflineConfig.enabled = true;
    await tester.pumpWidget(harness());
    await tester.pump();

    statusController.add(const SyncStatus(phase: SyncPhase.error));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sync error'), findsOneWidget);
  });

  testWidgets('tapping "Sync now" calls syncEngine.syncNow()', (tester) async {
    OfflineConfig.enabled = true;
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byTooltip('Sync now'));
    await tester.pump();

    verify(() => syncEngine.syncNow()).called(1);
  });

  testWidgets('flag OFF ⇒ SizedBox.shrink() regardless of status', (
    tester,
  ) async {
    OfflineConfig.enabled = false;
    await tester.pumpWidget(harness());
    await tester.pump();

    statusController.add(const SyncStatus(phase: SyncPhase.syncing));
    await tester.pump();

    expect(find.byTooltip('Sync now'), findsNothing);
    expect(find.textContaining('Sync'), findsNothing);
    final sizedBox = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 0 && widget.height == 0,
      ),
    );
    expect(sizedBox.width, 0);
    expect(sizedBox.height, 0);

    // Never touches the injected engine when the flag is off.
    verifyNever(() => syncEngine.statusStream);
    verifyNever(() => syncEngine.status);
  });
}
