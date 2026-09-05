// Mirrors `input_page_initstate_test.dart`'s shape:
// `ActivityPage.initState` must dispatch `WatchActivitiesEvent(sourceType:)`
// when the offline flag is on, and the legacy one-shot
// `GetActivitiesEvent(sourceType:)` when it is off — never both, never
// neither — passing the same `widget.sourceType` filter either way. Like
// `InputPage`, `ActivityPage.initState` always dispatches (no
// `is! ActivityLoaded` guard — see the page's own doc comment on why: the
// shared, parameterized `ActivityBloc` singleton's `Loaded` state doesn't
// record which `sourceType` produced it), so there is no "does not refetch
// when already loaded" case to assert here.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/activity_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivityBloc extends MockBloc<ActivityEvent, ActivityState>
    implements ActivityBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockCostCategoryBloc
    extends MockBloc<CostCategoryEvent, CostCategoryState>
    implements CostCategoryBloc {}

Widget _wrap(
  ActivityBloc bloc,
  HerdBloc herdBloc,
  SeasonBloc seasonBloc,
  LandBloc landBloc,
  CostCategoryBloc costCategoryBloc, {
  String? sourceType,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ActivityBloc>.value(value: bloc),
      BlocProvider<HerdBloc>.value(value: herdBloc),
      BlocProvider<SeasonBloc>.value(value: seasonBloc),
      BlocProvider<LandBloc>.value(value: landBloc),
      BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
    ],
    child: MaterialApp(home: ActivityPage(sourceType: sourceType)),
  );
}

void main() {
  late MockHerdBloc herdBloc;
  late MockSeasonBloc seasonBloc;
  late MockLandBloc landBloc;
  late MockCostCategoryBloc costCategoryBloc;

  setUpAll(() {
    registerFallbackValue(GetActivitiesEvent());
    registerFallbackValue(WatchActivitiesEvent());
  });

  setUp(() {
    herdBloc = MockHerdBloc();
    seasonBloc = MockSeasonBloc();
    landBloc = MockLandBloc();
    costCategoryBloc = MockCostCategoryBloc();
    whenListen(
      herdBloc,
      const Stream<HerdState>.empty(),
      initialState: const HerdLoaded([]),
    );
    whenListen(
      seasonBloc,
      const Stream<SeasonState>.empty(),
      initialState: const SeasonLoaded(seasons: []),
    );
    whenListen(
      landBloc,
      const Stream<LandState>.empty(),
      initialState: const LandLoaded(lands: []),
    );
    whenListen(
      costCategoryBloc,
      const Stream<CostCategoryState>.empty(),
      initialState: const CostCategoryLoaded([]),
    );
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets(
      'dispatches the one-shot GetActivitiesEvent(sourceType:)',
      (tester) async {
        final bloc = MockActivityBloc();
        whenListen(
          bloc,
          const Stream<ActivityState>.empty(),
          initialState: ActivityInitial(),
        );

        await tester.pumpWidget(
          _wrap(
            bloc,
            herdBloc,
            seasonBloc,
            landBloc,
            costCategoryBloc,
            sourceType: 'animal',
          ),
        );

        final captured = verify(
          () => bloc.add(captureAny(that: isA<GetActivitiesEvent>())),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as GetActivitiesEvent).sourceType, 'animal');
        verifyNever(() => bloc.add(any(that: isA<WatchActivitiesEvent>())));
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchActivitiesEvent(sourceType:) instead of '
      'GetActivitiesEvent',
      (tester) async {
        OfflineConfig.enabled = true;
        final bloc = MockActivityBloc();
        whenListen(
          bloc,
          const Stream<ActivityState>.empty(),
          initialState: ActivityInitial(),
        );

        await tester.pumpWidget(
          _wrap(
            bloc,
            herdBloc,
            seasonBloc,
            landBloc,
            costCategoryBloc,
            sourceType: 'animal',
          ),
        );

        final captured = verify(
          () => bloc.add(captureAny(that: isA<WatchActivitiesEvent>())),
        ).captured;
        expect(captured, hasLength(1));
        expect(
          (captured.single as WatchActivitiesEvent).sourceType,
          'animal',
        );
        verifyNever(() => bloc.add(any(that: isA<GetActivitiesEvent>())));
      },
    );
  });
}
