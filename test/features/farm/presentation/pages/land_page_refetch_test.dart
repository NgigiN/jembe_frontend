import 'package:bloc_test/bloc_test.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/land_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/land_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

Widget _wrap(LandBloc bloc) {
  return MaterialApp(
    home: BlocProvider<LandBloc>.value(value: bloc, child: const LandPage()),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(GetLandsEvent());
  });

  testWidgets('does not refetch when lands already loaded', (tester) async {
    final bloc = MockLandBloc();
    final now = DateTime.now();
    whenListen(
      bloc,
      const Stream<LandState>.empty(),
      initialState: LandLoaded(
        lands: [
          Land(
            id: 'land-1',
            userId: 'user-1',
            name: 'North Field',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(bloc));

    verifyNever(() => bloc.add(any(that: isA<GetLandsEvent>())));
  });

  testWidgets('fetches when not yet loaded', (tester) async {
    final bloc = MockLandBloc();
    whenListen(
      bloc,
      const Stream<LandState>.empty(),
      initialState: LandInitial(),
    );

    await tester.pumpWidget(_wrap(bloc));

    verify(() => bloc.add(any(that: isA<GetLandsEvent>()))).called(1);
  });
}
