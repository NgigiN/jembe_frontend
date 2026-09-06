// Mirrors `plant_page_initstate_test.dart`'s shape:
// `InfrastructurePage.initState` must dispatch `WatchInfrastructureEvent`
// when the offline flag is on, and the legacy one-shot
// `GetInfrastructuresEvent` when it is off — never both, never neither.
import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/infrastructure_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/infrastructure_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInfrastructureBloc
    extends MockBloc<InfrastructureEvent, InfrastructureState>
    implements InfrastructureBloc {}

Widget _wrap(InfrastructureBloc bloc) {
  return MaterialApp(
    home: BlocProvider<InfrastructureBloc>.value(
      value: bloc,
      child: const InfrastructurePage(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(GetInfrastructuresEvent());
    registerFallbackValue(WatchInfrastructureEvent());
  });

  tearDown(() {
    OfflineConfig.enabled = false;
  });

  group("flag OFF (today's one-shot behavior, unchanged)", () {
    testWidgets('does not refetch when infrastructures already loaded', (
      tester,
    ) async {
      final bloc = MockInfrastructureBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<InfrastructureState>.empty(),
        initialState: InfrastructureLoaded([
          Infrastructure(
            id: 'infra-1',
            userId: 'user-1',
            type: 'Barn',
            name: 'Main Barn',
            location: 'North Field',
            cost: 1000,
            date: now,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<GetInfrastructuresEvent>())));
      verifyNever(() => bloc.add(any(that: isA<WatchInfrastructureEvent>())));
    });

    testWidgets(
      'dispatches the one-shot GetInfrastructuresEvent when not yet loaded',
      (tester) async {
        final bloc = MockInfrastructureBloc();
        whenListen(
          bloc,
          const Stream<InfrastructureState>.empty(),
          initialState: InfrastructureInitial(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(
          () => bloc.add(any(that: isA<GetInfrastructuresEvent>())),
        ).called(1);
        verifyNever(() => bloc.add(any(that: isA<WatchInfrastructureEvent>())));
      },
    );
  });

  group('flag ON (reactive watch stream)', () {
    testWidgets(
      'dispatches WatchInfrastructureEvent instead of '
      'GetInfrastructuresEvent',
      (tester) async {
        OfflineConfig.enabled = true;
        final bloc = MockInfrastructureBloc();
        whenListen(
          bloc,
          const Stream<InfrastructureState>.empty(),
          initialState: InfrastructureInitial(),
        );

        await tester.pumpWidget(_wrap(bloc));

        verify(
          () => bloc.add(any(that: isA<WatchInfrastructureEvent>())),
        ).called(1);
        verifyNever(() => bloc.add(any(that: isA<GetInfrastructuresEvent>())));
      },
    );

    testWidgets('does not re-watch when infrastructures already loaded', (
      tester,
    ) async {
      OfflineConfig.enabled = true;
      final bloc = MockInfrastructureBloc();
      final now = DateTime.now();
      whenListen(
        bloc,
        const Stream<InfrastructureState>.empty(),
        initialState: InfrastructureLoaded([
          Infrastructure(
            id: 'infra-1',
            userId: 'user-1',
            type: 'Barn',
            name: 'Main Barn',
            location: 'North Field',
            cost: 1000,
            date: now,
            notes: '',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(bloc));

      verifyNever(() => bloc.add(any(that: isA<WatchInfrastructureEvent>())));
      verifyNever(() => bloc.add(any(that: isA<GetInfrastructuresEvent>())));
    });
  });
}
