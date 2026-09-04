import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:skeletonizer/skeletonizer.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState>
    implements LandBloc {}

/// Stubs the flutter_secure_storage platform channel so
/// UserUtils.getCurrentUserId() resolves without touching real native code.
void _mockSecureStorageUserId(String userId) {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'read') return userId;
    if (call.method == 'readAll') return <String, String>{};
    return null;
  });
}

void main() {
  testWidgets(
    'shows a skeleton (not a spinner) while lands are loading',
    (tester) async {
      final landBloc = MockLandBloc();
      whenListen(
        landBloc,
        Stream<LandState>.value(const LandLoading()),
        initialState: const LandLoading(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<LandBloc>.value(
            value: landBloc,
            child: const LandPage(),
          ),
        ),
      );

      final skeletonizerFinder = find.byWidgetPredicate(
        (widget) => widget is Skeletonizer,
      );
      expect(skeletonizerFinder, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  group('showAddLandDialog', () {
    late MockLandBloc landBloc;
    late StreamController<LandState> stateController;

    setUpAll(() {
      registerFallbackValue(GetLandsEvent());
    });

    setUp(() {
      _mockSecureStorageUserId('user-1');
      landBloc = MockLandBloc();
      stateController = StreamController<LandState>.broadcast();
      whenListen(
        landBloc,
        stateController.stream,
        initialState: const LandLoaded(lands: []),
      );
    });

    tearDown(() => stateController.close());

    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MaterialApp(
        home: BlocProvider<LandBloc>.value(
          value: landBloc,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddLandDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'returns the new land id once the bloc reports it added',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Land Name *'),
          'North Field',
        );

        // The sheet now awaits the bloc's terminal state before it confirms
        // and closes (P3-06), so the confirming state must be emitted after
        // the submit is tapped, not before.
        await tester.tap(find.text('Add Land'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final now = DateTime.now();
        stateController.add(
          LandLoaded(
            lands: [
              Land(
                id: 'land-42',
                userId: 'user-1',
                name: 'North Field',
                createdAt: now,
                updatedAt: now,
              ),
            ],
            successMessage: 'Land added',
          ),
        );
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, 'land-42');
      },
    );

    testWidgets(
      'submits the selected tenure type on the dispatched AddLandEvent',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Land Name *'),
          'North Field',
        );

        // The dropdown-menu-overlay open/select interaction is Flutter's own
        // widget behavior, already covered by the framework's tests; what
        // this test cares about is that selecting a value flows through to
        // the submitted event, so the callback is invoked directly rather
        // than fighting the overlay's tap mechanics.
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        );
        dropdown.onChanged!('rented');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add Land'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Let the sheet's post-dispatch await resolve so onSubmit completes.
        stateController.add(
          const LandLoaded(lands: [], successMessage: 'Land added'),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => resultFuture);

        final captured = verify(
          () => landBloc.add(captureAny()),
        ).captured;
        final event = captured.whereType<AddLandEvent>().single;
        expect(event.land.tenureType, 'rented');
      },
    );

    testWidgets(
      'returns null when the sheet is closed without submitting',
      (tester) async {
        late Future<String?> resultFuture;
        await tester.pumpWidget(
          buildHarness((future) => resultFuture = future),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        final result = await tester.runAsync(() => resultFuture);
        expect(result, isNull);
      },
    );
  });

  group('editing a land', () {
    late MockLandBloc landBloc;
    late StreamController<LandState> stateController;
    late Land existingLand;

    setUpAll(() {
      registerFallbackValue(GetLandsEvent());
    });

    setUp(() {
      _mockSecureStorageUserId('user-1');
      final now = DateTime.now();
      existingLand = Land(
        id: 'land-1',
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'owned',
        createdAt: now,
        updatedAt: now,
      );
      landBloc = MockLandBloc();
      stateController = StreamController<LandState>.broadcast();
      whenListen(
        landBloc,
        stateController.stream,
        initialState: LandLoaded(lands: [existingLand]),
      );
    });

    tearDown(() => stateController.close());

    testWidgets(
      'shows the tenure type, capitalized, in the land details sheet',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<LandBloc>.value(
              value: landBloc,
              child: const LandPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('North Field'));
        await tester.pumpAndSettle();

        expect(find.text('Owned'), findsOneWidget);
      },
    );

    testWidgets(
      'pre-fills the tenure dropdown from the land and submits the '
      'updated value on UpdateLandEvent',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<LandBloc>.value(
              value: landBloc,
              child: const LandPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('North Field'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        );
        expect(dropdown.initialValue, 'owned');

        dropdown.onChanged!('rented');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update Land'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The sheet awaits the bloc's terminal state before it closes (P3-06);
        // emit the confirming state so the update onSubmit resolves.
        stateController.add(
          LandLoaded(lands: [existingLand], successMessage: 'Land updated'),
        );
        await tester.pumpAndSettle();

        final captured = verify(
          () => landBloc.add(captureAny()),
        ).captured;
        final event = captured.whereType<UpdateLandEvent>().single;
        expect(event.land.tenureType, 'rented');
      },
    );
  });
}
