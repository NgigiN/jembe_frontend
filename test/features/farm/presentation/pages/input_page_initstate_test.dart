// Mirrors `harvest_page_initstate_test.dart`'s shape: `InputPage.initState`
// must dispatch `WatchInputsEvent(sourceType:)` when the offline flag is on,
// and the legacy one-shot `GetInputsEvent(sourceType:)` when it is off —
// never both, never neither — passing the same `widget.sourceType` filter
// either way. Unlike `HarvestPage`, `InputPage.initState` always dispatches
// (no `is! InputLoaded` guard — see the page's own doc comment on why: the
// shared, parameterized `InputBloc` singleton's `Loaded` state doesn't
// record which `sourceType` produced it), so there is no "does not refetch
// when already loaded" case to assert here.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/input_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/input_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInputBloc extends MockBloc<InputEvent, InputState>
    implements InputBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState>
    implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockCostCategoryBloc
    extends MockBloc<CostCategoryEvent, CostCategoryState>
    implements CostCategoryBloc {}

Widget _wrap(
  InputBloc bloc,
  HerdBloc herdBloc,
  SeasonBloc seasonBloc,
  LandBloc landBloc,
  CostCategoryBloc costCategoryBloc, {
  String? sourceType,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<InputBloc>.value(value: bloc),
      BlocProvider<HerdBloc>.value(value: herdBloc),
      BlocProvider<SeasonBloc>.value(value: seasonBloc),
      BlocProvider<LandBloc>.value(value: landBloc),
      BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
    ],
    child: MaterialApp(home: InputPage(sourceType: sourceType)),
  );
}

void main() {
  late MockHerdBloc herdBloc;
  late MockSeasonBloc seasonBloc;
  late MockLandBloc landBloc;
  late MockCostCategoryBloc costCategoryBloc;

  setUpAll(() {
    registerFallbackValue(GetInputsEvent());
    registerFallbackValue(WatchInputsEvent());
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
      'dispatches the one-shot GetInputsEvent(sourceType:)',
      (tester) async {
        final bloc = MockInputBloc();
        whenListen(
          bloc,
          const Stream<InputState>.empty(),
          initialState: InputInitial(),
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
          () => bloc.add(captureAny(that: isA<GetInputsEvent>())),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as GetInputsEvent).sourceType, 'animal');
        verifyNever(() => bloc.add(any(that: isA<WatchInputsEvent>())));
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchInputsEvent(sourceType:) instead of GetInputsEvent',
      (tester) async {
        OfflineConfig.enabled = true;
        final bloc = MockInputBloc();
        whenListen(
          bloc,
          const Stream<InputState>.empty(),
          initialState: InputInitial(),
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
          () => bloc.add(captureAny(that: isA<WatchInputsEvent>())),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.single as WatchInputsEvent).sourceType, 'animal');
        verifyNever(() => bloc.add(any(that: isA<GetInputsEvent>())));
      },
    );
  });
}
