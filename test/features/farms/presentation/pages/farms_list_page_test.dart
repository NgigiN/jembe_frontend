import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farms_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeFarmBloc extends Fake implements FarmBloc {
  _FakeFarmBloc(this._state);
  final FarmState _state;
  final List<FarmEvent> added = [];

  @override
  FarmState get state => _state;
  @override
  Stream<FarmState> get stream => Stream.value(_state);
  @override
  void add(FarmEvent event) => added.add(event);
  @override
  Future<void> close() async {}
}

Farm _farm(int id, {FarmRole role = FarmRole.owner}) => Farm(
  id: id,
  name: 'Farm $id',
  location: '',
  fiscalYearStartMonth: 1,
  ownerUserId: 1,
  successorUserId: null,
  maxMembers: 5,
  role: role,
  memberCount: 1,
  isDefault: id == 1,
);

void main() {
  testWidgets('lists every farm and marks the current one', (tester) async {
    final bloc = _FakeFarmBloc(
      FarmLoaded(
        farms: [
          _farm(1),
          _farm(2, role: FarmRole.worker),
        ],
        currentFarmId: 1,
        currentRole: FarmRole.owner,
      ),
    );

    await tester.pumpWidget(
      BlocProvider<FarmBloc>.value(
        value: bloc,
        child: const MaterialApp(home: FarmsListPage()),
      ),
    );

    expect(find.text('Farm 1'), findsOneWidget);
    expect(find.text('Farm 2'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping a non-current farm dispatches SwitchFarm', (
    tester,
  ) async {
    final bloc = _FakeFarmBloc(
      FarmLoaded(
        farms: [
          _farm(1),
          _farm(2, role: FarmRole.worker),
        ],
        currentFarmId: 1,
        currentRole: FarmRole.owner,
      ),
    );

    await tester.pumpWidget(
      BlocProvider<FarmBloc>.value(
        value: bloc,
        child: const MaterialApp(home: FarmsListPage()),
      ),
    );
    await tester.tap(find.text('Farm 2'));

    expect(bloc.added, [const SwitchFarm(2)]);
  });

  // The page used to render a bare spinner for every state that was not
  // FarmLoaded, while dispatching nothing. The only LoadFarms in the app fires
  // once in main(); if that call failed or had not finished - cold start, fresh
  // install, slow network - this page spun forever with no retry and no
  // message. It was reported as "loaded forever" on a freshly installed build.

  testWidgets(
    'asks for farms when the bloc has none, rather than waiting to be given '
    'them by somebody else',
    (tester) async {
      final bloc = _FakeFarmBloc(FarmInitial());

      await tester.pumpWidget(
        BlocProvider<FarmBloc>.value(
          value: bloc,
          child: const MaterialApp(home: FarmsListPage()),
        ),
      );

      expect(
        bloc.added.whereType<LoadFarms>(),
        isNotEmpty,
        reason:
            'a page that needs farms must ask for them; the spinner is '
            'otherwise permanent',
      );
    },
  );

  testWidgets(
    'shows the error and a retry when loading failed, instead of a spinner '
    'that never resolves',
    (tester) async {
      final bloc = _FakeFarmBloc(const FarmError('Could not reach the server'));

      await tester.pumpWidget(
        BlocProvider<FarmBloc>.value(
          value: bloc,
          child: const MaterialApp(home: FarmsListPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(EntityErrorView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Could not reach the server'), findsOneWidget);
    },
  );

  testWidgets('the retry asks for farms again', (tester) async {
    final bloc = _FakeFarmBloc(const FarmError('Could not reach the server'));

    await tester.pumpWidget(
      BlocProvider<FarmBloc>.value(
        value: bloc,
        child: const MaterialApp(home: FarmsListPage()),
      ),
    );
    await tester.pump();
    bloc.added.clear();
    await tester.tap(find.text('Try Again'));

    expect(bloc.added.whereType<LoadFarms>(), isNotEmpty);
  });

  testWidgets(
    'a farm list that loaded and is genuinely empty reads as empty, not as '
    'still loading',
    (tester) async {
      final bloc = _FakeFarmBloc(
        const FarmLoaded(
          farms: [],
          currentFarmId: null,
          currentRole: FarmRole.owner,
        ),
      );

      await tester.pumpWidget(
        BlocProvider<FarmBloc>.value(
          value: bloc,
          child: const MaterialApp(home: FarmsListPage()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
