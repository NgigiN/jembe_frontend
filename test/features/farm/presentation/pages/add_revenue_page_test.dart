import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/revenue_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/revenue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRevenueBloc extends MockBloc<RevenueEvent, RevenueState>
    implements RevenueBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState>
    implements HerdBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(GetSeasonsEvent());
    registerFallbackValue(GetHerdsEvent());
  });

  testWidgets(
    'Add Revenue page keeps its Save button clear of the system nav bar',
    (tester) async {
      final revenueBloc = MockRevenueBloc();
      final seasonBloc = MockSeasonBloc();
      final herdBloc = MockHerdBloc();

      whenListen(
        revenueBloc,
        Stream<RevenueState>.value(RevenueInitial()),
        initialState: RevenueInitial(),
      );
      whenListen(
        seasonBloc,
        Stream<SeasonState>.value(const SeasonLoaded(seasons: [])),
        initialState: const SeasonLoaded(seasons: []),
      );
      whenListen(
        herdBloc,
        Stream<HerdState>.value(const HerdLoaded([])),
        initialState: const HerdLoaded([]),
      );

      // Use a realistic phone-sized viewport - the default test surface
      // (2400x1800 logical @ ratio 1.0) is tall enough that the form never
      // needs to scroll at all, which would make this test pass regardless
      // of whether the padding fix is present.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 700);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<RevenueBloc>.value(value: revenueBloc),
              BlocProvider<SeasonBloc>.value(value: seasonBloc),
              BlocProvider<HerdBloc>.value(value: herdBloc),
            ],
            child: const AddRevenuePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The form is taller than the test viewport, so scroll to the very
      // bottom before measuring the Save button's position.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      final buttonBottom = tester
          .getBottomLeft(find.widgetWithText(FilledButton, 'Save Revenue'))
          .dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        buttonBottom,
        lessThanOrEqualTo(screenHeight - 48),
        reason: 'Save Revenue button must clear the 48px system nav bar inset',
      );
    },
  );
}
