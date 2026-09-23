import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  setUpAll(() => registerFallbackValue(GetDashboardEvent()));

  testWidgets('renders counts and totals from DashboardLoaded', (tester) async {
    final bloc = MockDashboardBloc();
    const loaded = DashboardLoaded(
      counts: DashboardCounts(
        lands: 3, plants: 12, seasons: 2, harvests: 7, animalTypes: 4, herds: 5,
      ),
      totals: DashboardTotals(totalCosts: 100, totalRevenue: 250, profit: 150),
    );
    whenListen(bloc, const Stream<DashboardState>.empty(), initialState: loaded);

    await tester.pumpWidget(
      BlocProvider<DashboardBloc>.value(
        value: bloc, child: const MaterialApp(home: WebDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('dispatches GetDashboardEvent on init', (tester) async {
    final bloc = MockDashboardBloc();
    whenListen(bloc, const Stream<DashboardState>.empty(), initialState: const DashboardInitial());

    await tester.pumpWidget(
      BlocProvider<DashboardBloc>.value(
        value: bloc, child: const MaterialApp(home: WebDashboardPage()),
      ),
    );
    await tester.pump();

    verify(() => bloc.add(any(that: isA<GetDashboardEvent>()))).called(1);
  });
}
