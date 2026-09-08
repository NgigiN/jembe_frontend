import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analytics/annual_summary_page.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

MockLandBloc _landBloc() {
  final bloc = MockLandBloc();
  final land = Land(
    id: 'l1',
    userId: 'u',
    name: 'Shamba A',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  whenListen(
    bloc,
    Stream<LandState>.value(LandLoaded(lands: [land])),
    initialState: LandLoaded(lands: [land]),
  );
  return bloc;
}

MockHerdBloc _herdBloc() {
  final bloc = MockHerdBloc();
  whenListen(
    bloc,
    Stream<HerdState>.value(const HerdLoaded([])),
    initialState: const HerdLoaded([]),
  );
  return bloc;
}

MockProfileBloc _profileBloc({int fiscalYearStartMonth = 7}) {
  final bloc = MockProfileBloc();
  final user = User(
    id: '1',
    email: 'a@example.com',
    firstName: 'A',
    lastName: 'B',
    farmName: 'Green Acres',
    location: 'Nakuru',
    pictureUrl: '',
    fiscalYearStartMonth: fiscalYearStartMonth,
  );
  whenListen(
    bloc,
    Stream<ProfileState>.value(ProfileLoaded(user: user)),
    initialState: ProfileLoaded(user: user),
  );
  return bloc;
}

Widget _wrap({required AnalysisBloc analysis, required ProfileBloc profile}) =>
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AnalysisBloc>.value(value: analysis),
          BlocProvider<ProfileBloc>.value(value: profile),
          BlocProvider<LandBloc>.value(value: _landBloc()),
          BlocProvider<HerdBloc>.value(value: _herdBloc()),
        ],
        child: const AnnualSummaryPage(),
      ),
    );

MonthlySummary _summary(String month, double revenue, double costs) {
  return MonthlySummary(
    month: month,
    totalCosts: costs,
    totalRevenue: revenue,
    profit: revenue - costs,
    breakdown: const MonthlySummaryBreakdown(
      costs: MonthlyCostBreakdown(plant: 0, animal: 0, infrastructure: 0),
      revenue: MonthlyRevenueBreakdown(plant: 0, animal: 0),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadTotalCostsBySeason());
    registerFallbackValue(GetLandsEvent());
    registerFallbackValue(GetHerdsEvent());
  });

  testWidgets(
    'computes the farm-year from the profile fiscal month and supports prev/next navigation',
    (tester) async {
      final analysisBloc = MockAnalysisBloc();
      final profileBloc = MockProfileBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
        fiscalYearStartMonth: 7,
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );

      final decSummary = _summary('2025-12', 300, 100);
      whenListen(
        analysisBloc,
        Stream<AnalysisState>.value(
          AnalysisState(summaries: AnalysisSlice(data: [decSummary])),
        ),
        initialState: AnalysisState(
          summaries: AnalysisSlice(data: [decSummary]),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisBloc>.value(value: analysisBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<LandBloc>.value(value: _landBloc()),
              BlocProvider<HerdBloc>.value(value: _herdBloc()),
            ],
            child: const AnnualSummaryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fiscal year starts in July, so a farm-year label like 20XX/YY shows,
      // not a plain calendar year.
      expect(find.textContaining('Farm Year 20'), findsOneWidget);
      expect(find.textContaining('/'), findsWidgets);

      verify(
        () => analysisBloc.add(any(that: isA<LoadAnnualCostSummary>())),
      ).called(greaterThanOrEqualTo(1));

      // Tap previous — should dispatch another LoadAnnualCostSummary.
      // (mocktail's `verify` above already consumed prior interactions, so
      // this checks only the call triggered by this tap.)
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(
        () => analysisBloc.add(any(that: isA<LoadAnnualCostSummary>())),
      ).called(1);
    },
  );

  testWidgets(
    'shows the farm-year switcher (not just a dead-end error) when a load fails, and keeps prev navigation working',
    (tester) async {
      final analysisBloc = MockAnalysisBloc();
      final profileBloc = MockProfileBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );

      whenListen(
        analysisBloc,
        Stream<AnalysisState>.value(
          const AnalysisState(
            summaries: AnalysisSlice(
              error: 'Something went wrong. Please try again.',
            ),
          ),
        ),
        initialState: const AnalysisState(
          summaries: AnalysisSlice(
            error: 'Something went wrong. Please try again.',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisBloc>.value(value: analysisBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<LandBloc>.value(value: _landBloc()),
              BlocProvider<HerdBloc>.value(value: _herdBloc()),
            ],
            child: const AnnualSummaryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The year switcher must stay visible and usable even on error -
      // otherwise a user who pages back into a failing year is stuck.
      expect(find.textContaining('Farm Year 20'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      // Consume the initial-mount dispatch so the check below only counts
      // the one triggered by the tap (mocktail's verify resets on each call).
      verify(
        () => analysisBloc.add(any(that: isA<LoadAnnualCostSummary>())),
      ).called(greaterThanOrEqualTo(1));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(
        () => analysisBloc.add(any(that: isA<LoadAnnualCostSummary>())),
      ).called(1);
    },
  );

  testWidgets(
    'tapping Plants dispatches AnalysisScopeChanged and keeps the farm year',
    (tester) async {
      final analysisBloc = MockAnalysisBloc();
      final summary = _summary('2025-12', 300, 100);
      final state = AnalysisState(summaries: AnalysisSlice(data: [summary]));
      whenListen(
        analysisBloc,
        Stream<AnalysisState>.value(state),
        initialState: state,
      );

      await tester.pumpWidget(
        _wrap(analysis: analysisBloc, profile: _profileBloc()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plants'));
      verify(
        () => analysisBloc.add(
          const AnalysisScopeChanged(AnalyticsScope.source(ScopeSource.plant)),
        ),
      ).called(1);
      expect(find.textContaining('Farm Year 20'), findsOneWidget);
    },
  );

  testWidgets('Infra row hidden under a land scope, shown farm-wide', (
    tester,
  ) async {
    final summary = _summary('2025-12', 300, 100);
    final farmWide = AnalysisState(summaries: AnalysisSlice(data: [summary]));
    final landScoped = farmWide.copyWith(
      scope: const AnalyticsScope.land('l1'),
    );

    final farmWideBloc = MockAnalysisBloc();
    whenListen(
      farmWideBloc,
      Stream<AnalysisState>.value(farmWide),
      initialState: farmWide,
    );
    await tester.pumpWidget(
      _wrap(analysis: farmWideBloc, profile: _profileBloc()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Infra'), findsOneWidget);

    final landBloc = MockAnalysisBloc();
    whenListen(
      landBloc,
      Stream<AnalysisState>.value(landScoped),
      initialState: landScoped,
    );
    await tester.pumpWidget(_wrap(analysis: landBloc, profile: _profileBloc()));
    await tester.pumpAndSettle();
    expect(find.text('Infra'), findsNothing);
    expect(find.text('Shamba A'), findsOneWidget, reason: 'land chip shown');
  });
}
