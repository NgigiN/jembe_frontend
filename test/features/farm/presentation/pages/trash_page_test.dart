import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/trash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTrashBloc extends MockBloc<TrashEvent, TrashState>
    implements TrashBloc {}

const _land = TrashItem(entity: 'land', id: '1', label: 'North Field');
const _season = TrashItem(entity: 'season', id: '2', label: 'Long Rains');

void main() {
  late MockTrashBloc trashBloc;

  setUpAll(() {
    registerFallbackValue(LoadTrashEvent());
    registerFallbackValue(RestoreItemEvent(entity: 'land', id: '1'));
  });

  setUp(() {
    trashBloc = MockTrashBloc();
  });

  Widget wrap() {
    return MaterialApp(
      home: BlocProvider<TrashBloc>.value(
        value: trashBloc,
        child: const TrashPage(),
      ),
    );
  }

  testWidgets(
    'dispatches LoadTrashEvent once on init when not already loaded',
    (tester) async {
      whenListen(
        trashBloc,
        const Stream<TrashState>.empty(),
        initialState: const TrashInitial(),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      verify(() => trashBloc.add(any(that: isA<LoadTrashEvent>()))).called(1);
    },
  );

  testWidgets(
    'renders items grouped by entity under a section header per entity',
    (tester) async {
      whenListen(
        trashBloc,
        const Stream<TrashState>.empty(),
        initialState: const TrashLoaded(items: [_land, _season]),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Lands'), findsOneWidget);
      expect(find.text('North Field'), findsOneWidget);
      expect(find.text('Seasons'), findsOneWidget);
      expect(find.text('Long Rains'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsNWidgets(2));
    },
  );

  testWidgets('shows the empty state when there is nothing in the trash', (
    tester,
  ) async {
    whenListen(
      trashBloc,
      const Stream<TrashState>.empty(),
      initialState: const TrashLoaded(items: []),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Nothing in the trash'), findsOneWidget);
    expect(find.byIcon(Icons.restore), findsNothing);
  });

  testWidgets('tapping Restore dispatches RestoreItemEvent for that item', (
    tester,
  ) async {
    whenListen(
      trashBloc,
      const Stream<TrashState>.empty(),
      initialState: const TrashLoaded(items: [_land]),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pump();

    verify(
      () => trashBloc.add(
        any(
          that: isA<RestoreItemEvent>()
              .having((e) => e.entity, 'entity', 'land')
              .having((e) => e.id, 'id', '1'),
        ),
      ),
    ).called(1);
  });

  testWidgets('a restore success emits a snackbar with the success message', (
    tester,
  ) async {
    whenListen(
      trashBloc,
      Stream.fromIterable([
        const TrashLoaded(
          items: [_season],
          successMessage: 'North Field restored',
        ),
      ]),
      initialState: const TrashLoaded(items: [_land, _season]),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump();

    expect(find.text('North Field restored'), findsOneWidget);

    // Drain the SnackBar's display/dismiss timer so no timer is left
    // pending when the test ends.
    await tester.pumpAndSettle();
  });

  testWidgets(
    'a 409 conflict emits a snackbar with the conflict message and keeps '
    'the item',
    (tester) async {
      whenListen(
        trashBloc,
        Stream.fromIterable([
          const TrashLoaded(
            items: [_land, _season],
            conflictMessage: 'plant is still deleted',
          ),
        ]),
        initialState: const TrashLoaded(items: [_land, _season]),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();
      await tester.pump();

      expect(find.text('plant is still deleted'), findsOneWidget);
      // Not removed: still rendered in the list.
      expect(find.text('Long Rains'), findsOneWidget);

      // Drain the SnackBar's display/dismiss timer so no timer is left
      // pending when the test ends.
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'an empty-items error state shows the error message with a retry '
    'action',
    (tester) async {
      whenListen(
        trashBloc,
        const Stream<TrashState>.empty(),
        initialState: const TrashError('Failed to load trash'),
      );

      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Failed to load trash'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    },
  );
}
