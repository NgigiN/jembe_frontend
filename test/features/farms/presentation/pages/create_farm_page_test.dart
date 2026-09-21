import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/data/models/farm_model.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_event.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/farms/presentation/pages/create_farm_page.dart';
import 'package:farm_tracker/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements FarmRemoteDataSource {}
class _FakeFarmBloc extends Fake implements FarmBloc {
  final List<FarmEvent> added = [];
  @override
  void add(FarmEvent event) => added.add(event);
  @override
  Stream<FarmState> get stream => const Stream.empty();
  @override
  FarmState get state => FarmInitial();
}

void main() {
  late _MockRemote remote;
  late _FakeFarmBloc farmBloc;

  setUp(() async {
    await GetIt.instance.reset();
    remote = _MockRemote();
    farmBloc = _FakeFarmBloc();
    sl.registerSingleton<FarmRemoteDataSource>(remote);
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets('submitting the form calls createFarm and refreshes FarmBloc',
      (tester) async {
    when(() => remote.createFarm(
      name: any(named: 'name'),
      location: any(named: 'location'),
      fiscalYearStartMonth: any(named: 'fiscalYearStartMonth'),
    )).thenAnswer((_) async => FarmModel.fromJson(const {
      'id': 1, 'name': 'New Farm', 'location': '', 'fiscal_year_start_month': 1,
      'owner_user_id': 1, 'successor_user_id': null, 'max_members': 5,
      'role': 'owner', 'member_count': 1, 'is_default': false,
    }));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/create', builder: (context, state) => const CreateFarmPage()),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<FarmBloc>.value(
        value: farmBloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/create');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('create_farm_name')), 'New Farm');
    await tester.tap(find.byKey(const Key('create_farm_submit')));
    await tester.pumpAndSettle();

    verify(() => remote.createFarm(
      name: 'New Farm', location: '', fiscalYearStartMonth: 1,
    )).called(1);
    expect(farmBloc.added, [isA<RefreshFarms>()]);
  });
}
