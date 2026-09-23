import 'package:farm_tracker/features/web_console/data/console_log_service.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/log_entry_dialog.dart';
import 'package:farm_tracker/features/web_console/presentation/theme/web_console_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../web_console/fake_log_writer.dart';

Future<void> _pump(WidgetTester tester, LogEntryKind kind, FakeLogWriter writer) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: WebConsoleTheme.light(),
      home: Scaffold(body: LogEntryDialog(kind: kind, service: writer)),
    ),
  );
  await tester.pump();
}

/// Finds a field by its placeholder, which is stabler than counting the
/// TextFormFields down the form.
Finder _field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

void main() {
  testWidgets('a sale posts the quantity and unit price it was given', (
    tester,
  ) async {
    final writer = FakeLogWriter();
    await _pump(tester, LogEntryKind.revenue, writer);

    await tester.enterText(_field('Milk, maize…'), 'Milk');
    await tester.enterText(_field('0').first, '120');
    await tester.enterText(_field('0').last, '55');
    await tester.pump();

    await tester.tap(find.text('Log sale'));
    await tester.pumpAndSettle();

    expect(writer.calls, hasLength(1));
    final call = writer.calls.single;
    expect(call['kind'], 'revenue');
    expect(call['type'], 'Milk');
    expect(call['quantity'], 120.0);
    expect(call['unitPrice'], 55.0);
    // Defaults to the plant side, and to the farm's only season.
    expect(call['source'], 'plant');
    expect(call['sourceId'], 's1');
  });

  testWidgets('the running total follows quantity times unit price', (
    tester,
  ) async {
    await _pump(tester, LogEntryKind.revenue, FakeLogWriter());

    await tester.enterText(_field('0').first, '120');
    await tester.enterText(_field('0').last, '55');
    await tester.pump();

    expect(find.text('KES 6,600'), findsOneWidget);
  });

  testWidgets('an empty required field blocks the write', (tester) async {
    final writer = FakeLogWriter();
    await _pump(tester, LogEntryKind.input, writer);

    await tester.tap(find.text('Log input'));
    await tester.pumpAndSettle();

    expect(writer.calls, isEmpty);
    expect(find.text('Add the input type.'), findsOneWidget);
    expect(find.text('Add the cost.'), findsOneWidget);
  });

  testWidgets('a herd event posts against the herd, not a season', (
    tester,
  ) async {
    final writer = FakeLogWriter();
    await _pump(tester, LogEntryKind.herdActivity, writer);

    await tester.enterText(_field('1'), '3');
    await tester.pump();
    await tester.tap(find.text('Log event'));
    await tester.pumpAndSettle();

    final call = writer.calls.single;
    expect(call['kind'], 'herdActivity');
    expect(call['herdId'], 'h1');
    expect(call['activityType'], 'birth');
    expect(call['count'], 3);
  });

  testWidgets('a farm with only herds lands on the herd form', (tester) async {
    final writer = FakeLogWriter(
      data: LogReference(
        seasons: const [],
        lands: const [],
        herds: sampleLogReference.herds,
        categories: sampleLogReference.categories,
      ),
    );
    await _pump(tester, LogEntryKind.input, writer);

    expect(find.text('Herd'), findsOneWidget);
    expect(find.textContaining('Start a season first'), findsNothing);
  });

  testWidgets('a farm with nothing set up says which thing is missing', (
    tester,
  ) async {
    final writer = FakeLogWriter(data: const LogReference.empty());
    await _pump(tester, LogEntryKind.harvest, writer);

    expect(find.textContaining('Start a season first'), findsOneWidget);
    // Nothing to submit, so the action is off.
    final button = find.widgetWithText(FilledButton, 'Log harvest');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('a failed write keeps the form open and says nothing was saved', (
    tester,
  ) async {
    final writer = FakeLogWriter(failWrite: true);
    await _pump(tester, LogEntryKind.harvest, writer);

    await tester.enterText(_field('0'), '18');
    await tester.pump();
    await tester.tap(find.text('Log harvest'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nothing was recorded'), findsOneWidget);
    expect(find.text('Log harvest'), findsOneWidget);
  });

  testWidgets('a reference failure offers a retry rather than empty pickers', (
    tester,
  ) async {
    final writer = FakeLogWriter(failReference: true);
    await _pump(tester, LogEntryKind.activity, writer);
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't load"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(writer.referenceLoads, greaterThan(1));
  });

  testWidgets('a plot needs no season or herd to exist first', (tester) async {
    final writer = FakeLogWriter(data: const LogReference.empty());
    await _pump(tester, LogEntryKind.land, writer);

    // The one form that works on a farm with nothing in it yet.
    expect(find.textContaining('Start a season first'), findsNothing);

    await tester.enterText(_field('West Plot'), 'East Plot');
    await tester.enterText(_field('1.2 (optional)'), '0.8');
    await tester.tap(find.text('Rented'));
    await tester.pump();
    await tester.tap(find.text('Add plot'));
    await tester.pumpAndSettle();

    final call = writer.calls.single;
    expect(call['kind'], 'land');
    expect(call['name'], 'East Plot');
    expect(call['size'], 0.8);
    expect(call['tenureType'], 'rented');
  });
}
