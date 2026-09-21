import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/data/models/farm_invitation_model.dart';
import 'package:farm_tracker/features/farms/data/models/farm_member_model.dart';
import 'package:farm_tracker/features/farms/data/models/farm_transfer_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/farms/presentation/pages/farm_manage_page.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements FarmRemoteDataSource {}
class _FakeFarmBloc extends Fake implements FarmBloc {
  _FakeFarmBloc(this._state);
  final FarmState _state;
  @override
  FarmState get state => _state;
  @override
  Stream<FarmState> get stream => Stream.value(_state);
  @override
  void add(dynamic event) {}
}

Farm _farm(FarmRole role) => Farm(
  id: 1, name: 'Farm', location: '', fiscalYearStartMonth: 1,
  ownerUserId: 1, successorUserId: null, maxMembers: 5,
  role: role, memberCount: 2, isDefault: true,
);

Future<void> _pump(WidgetTester tester, FarmRole role) async {
  await tester.pumpWidget(
    BlocProvider<FarmBloc>.value(
      value: _FakeFarmBloc(FarmLoaded(farms: [_farm(role)], currentFarmId: 1, currentRole: role)),
      child: const MaterialApp(home: FarmManagePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _MockRemote remote;

  setUp(() async {
    await GetIt.instance.reset();
    remote = _MockRemote();
    sl.registerSingleton<FarmRemoteDataSource>(remote);
    when(() => remote.listMembers()).thenAnswer((_) async => [
      FarmMemberModel.fromJson({
        'user_id': 1, 'first_name': 'Amina', 'last_name': 'Otieno',
        'email': 'a@example.com', 'role': 'owner', 'joined_at': '2026-01-01T00:00:00Z',
      }),
      FarmMemberModel.fromJson({
        'user_id': 2, 'first_name': 'Ben', 'last_name': 'Kamau',
        'email': 'b@example.com', 'role': 'worker', 'joined_at': '2026-01-01T00:00:00Z',
      }),
    ]);
    when(() => remote.listInvitations()).thenAnswer((_) async => <FarmInvitationModel>[]);
    when(() => remote.getTransfer()).thenAnswer((_) async => null);
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('shows every member for a worker, with no invite/role-change '
      'controls', (tester) async {
    await _pump(tester, FarmRole.worker);

    expect(find.text('Amina Otieno'), findsOneWidget);
    expect(find.text('Ben Kamau'), findsOneWidget);
    expect(find.byKey(const Key('invite_member_button')), findsNothing);
  });

  testWidgets('shows the invite control for a manager', (tester) async {
    await _pump(tester, FarmRole.manager);

    expect(find.byKey(const Key('invite_member_button')), findsOneWidget);
  });

  testWidgets('owner sees a nominate-successor control when no transfer is '
      'pending', (tester) async {
    await _pump(tester, FarmRole.owner);

    expect(find.text('No pending transfer'), findsOneWidget);
    expect(find.byKey(const Key('nominate_transfer_button')), findsOneWidget);
  });

  testWidgets('owner sees a cancel control when a transfer is pending',
      (tester) async {
    when(() => remote.getTransfer()).thenAnswer((_) async => FarmTransferModel.fromJson({
      'id': 1, 'farm_id': 1, 'from_user_id': 1, 'to_user_id': 2,
      'expires_at': '2026-10-01T00:00:00Z', 'created_at': '2026-09-21T00:00:00Z',
    }));

    await _pump(tester, FarmRole.owner);

    expect(find.text('Transfer pending'), findsOneWidget);
    expect(find.byKey(const Key('cancel_transfer_button')), findsOneWidget);
  });
}
