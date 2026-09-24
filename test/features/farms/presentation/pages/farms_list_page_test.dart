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
  id: id, name: 'Farm $id', location: '', fiscalYearStartMonth: 1,
  ownerUserId: 1, successorUserId: null, maxMembers: 5,
  role: role, memberCount: 1, isDefault: id == 1,
);

void main() {
  testWidgets('lists every farm and marks the current one', (tester) async {
    final bloc = _FakeFarmBloc(FarmLoaded(
      farms: [_farm(1), _farm(2, role: FarmRole.worker)],
      currentFarmId: 1,
      currentRole: FarmRole.owner,
    ));

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

  testWidgets('tapping a non-current farm dispatches SwitchFarm', (tester) async {
    final bloc = _FakeFarmBloc(FarmLoaded(
      farms: [_farm(1), _farm(2, role: FarmRole.worker)],
      currentFarmId: 1,
      currentRole: FarmRole.owner,
    ));

    await tester.pumpWidget(
      BlocProvider<FarmBloc>.value(
        value: bloc,
        child: const MaterialApp(home: FarmsListPage()),
      ),
    );
    await tester.tap(find.text('Farm 2'));

    expect(bloc.added, [const SwitchFarm(2)]);
  });
}
