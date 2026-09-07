import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockContentBloc extends MockBloc<ContentEvent, ContentState>
    implements ContentBloc {}

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

void main() {
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;
  late MockContentBloc contentBloc;
  late MockDashboardBloc dashboardBloc;

  setUpAll(() {
    registerFallbackValue(GetAnimalTypesEvent());
    registerFallbackValue(GetHerdsEvent());
    registerFallbackValue(GetDashboardEvent());
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  Widget harness() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
          BlocProvider<HerdBloc>.value(value: herdBloc),
          BlocProvider<ContentBloc>.value(value: contentBloc),
          BlocProvider<DashboardBloc>.value(value: dashboardBloc),
        ],
        child: const AnimalsPage(),
      ),
    );
  }

  testWidgets('the individual-animals step is locked until a herd exists', (
    tester,
  ) async {
    animalTypeBloc = MockAnimalTypeBloc();
    herdBloc = MockHerdBloc();
    contentBloc = MockContentBloc();
    dashboardBloc = MockDashboardBloc();
    whenListen(
      animalTypeBloc,
      const Stream<AnimalTypeState>.empty(),
      initialState: const AnimalTypeLoaded([]),
    );
    whenListen(
      herdBloc,
      const Stream<HerdState>.empty(),
      initialState: const HerdLoaded([]),
    );
    whenListen(
      contentBloc,
      const Stream<ContentState>.empty(),
      initialState: ContentInitial(),
    );
    whenListen(
      dashboardBloc,
      const Stream<DashboardState>.empty(),
      initialState: const DashboardLoaded(
        counts: DashboardCounts.zero(),
        totals: DashboardTotals.zero(),
      ),
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Track Individual Animals'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track Individual Animals'), findsOneWidget);
  });
}
