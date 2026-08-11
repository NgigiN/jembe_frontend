import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/features/auth/domain/entities/user.dart';
import 'package:farm_tracker/features/farm/domain/entities/monthly_summary.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/analysis_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/pages/analysis_page.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_event.dart';
import 'package:farm_tracker/features/profile/presentation/bloc/profile_state.dart';

class MockAnalysisBloc extends MockBloc<AnalysisEvent, AnalysisState>
    implements AnalysisBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

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
    registerFallbackValue(LoadTotalCostsBySeason());
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
        Stream<AnalysisState>.value(AnnualCostSummaryLoaded([decSummary])),
        initialState: AnnualCostSummaryLoaded([decSummary]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisBloc>.value(value: analysisBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
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
        () => analysisBloc.add(
          any(that: isA<LoadAnnualCostSummary>()),
        ),
      ).called(greaterThanOrEqualTo(1));

      // Tap previous — should dispatch another LoadAnnualCostSummary.
      // (mocktail's `verify` above already consumed prior interactions, so
      // this checks only the call triggered by this tap.)
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(
        () => analysisBloc.add(
          any(that: isA<LoadAnnualCostSummary>()),
        ),
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
        fiscalYearStartMonth: 1,
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );

      whenListen(
        analysisBloc,
        Stream<AnalysisState>.value(
          const AnalysisError('Something went wrong. Please try again.'),
        ),
        initialState: const AnalysisError(
          'Something went wrong. Please try again.',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AnalysisBloc>.value(value: analysisBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
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
        () => analysisBloc.add(
          any(that: isA<LoadAnnualCostSummary>()),
        ),
      ).called(greaterThanOrEqualTo(1));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      verify(
        () => analysisBloc.add(
          any(that: isA<LoadAnnualCostSummary>()),
        ),
      ).called(1);
    },
  );
}
