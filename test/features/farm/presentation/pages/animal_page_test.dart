import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_page.dart';

class MockAnimalBloc extends MockBloc<AnimalEvent, AnimalState>
    implements AnimalBloc {}

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

final now = DateTime.now();

Widget _harness({
  required AnimalBloc animalBloc,
  required AnimalTypeBloc animalTypeBloc,
  required HerdBloc herdBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AnimalBloc>.value(value: animalBloc),
        BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
        BlocProvider<HerdBloc>.value(value: herdBloc),
      ],
      child: const AnimalPage(),
    ),
  );
}

void main() {
  late MockAnimalBloc animalBloc;
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;

  setUp(() {
    animalBloc = MockAnimalBloc();
    animalTypeBloc = MockAnimalTypeBloc();
    herdBloc = MockHerdBloc();
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
  });

  testWidgets('shows a skeleton (not a spinner) while animals are loading', (
    tester,
  ) async {
    whenListen(
      animalBloc,
      Stream<AnimalState>.value(const AnimalLoading()),
      initialState: const AnimalLoading(),
    );

    await tester.pumpWidget(
      _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
    );

    final skeletonizerFinder = find.byWidgetPredicate(
      (widget) => widget is Skeletonizer,
    );
    expect(skeletonizerFinder, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders one card per loaded animal', (tester) async {
    final animal = Animal(
      id: 'animal-1',
      userId: 'user-1',
      name: 'Bessie',
      animalTypeId: 'type-1',
      herdId: 'herd-1',
      birthDate: now,
      createdAt: now,
      updatedAt: now,
    );
    whenListen(
      animalBloc,
      Stream<AnimalState>.value(AnimalLoaded(animals: [animal])),
      initialState: AnimalLoaded(animals: [animal]),
    );

    await tester.pumpWidget(
      _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bessie'), findsOneWidget);
  });
}
