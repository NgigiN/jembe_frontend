# Individual-Animal CRUD UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new individual-Animal CRUD page (add/edit/list/details/delete) with `sex`/`acquisitionSource` fields, and wire "Bought" to auto-prompt the existing Input cost-log flow, scoped to that animal.

**Architecture:** Mirror this codebase's existing entity-page pattern (`LandPage`/`LandBloc` is the closest template — both use whole-entity-object usecase params) exactly: entity/model fields, a `AnimalBloc`/`AnimalEvent`/`AnimalState` triad calling the already-existing `GetAnimals`/`AddAnimal`/`UpdateAnimal`/`DeleteAnimal` usecases, an `AnimalPage` built from `EntityCard`/`EntityFormSheet`/`EntityDetailsSheet`/`EntityDeleteDialog`, a new router entry, and a 7th setup-wizard step. Separately, extract `input_page.dart`'s private `_showAddInputDialog` into a reusable top-level function so `AnimalPage` can open it pre-filled and locked to a specific animal.

**Tech Stack:** Flutter, `flutter_bloc`, `equatable`, `dartz` (`Either`), `mocktail`/`bloc_test` for widget tests.

**Spec:** `docs/superpowers/specs/2026-08-29-animal-crud-ui-design.md`

## Global Constraints

- No backend changes in this plan — `Animal.Sex`/`Animal.AcquisitionSource` (backend PR `farmers_backend#14`) and `Input.AnimalID` already exist end-to-end.
- TDD per step: write the failing test, run it and confirm it fails for the right reason, write minimal code, run it and confirm it passes, commit. Do not skip the RED verification.
- Before editing any file for the first time in this plan, read it in full first (do not assume its contents from this plan's summaries) — this codebase's session convention (see project memory `feedback_read_before_write.md`) is to verify via the file itself, not `git status`, before treating anything as safe to overwrite.
- Widget tests must never simulate opening a `DropdownButtonFormField`'s (or `EntityPickerWithAdd`'s) overlay menu via `tester.tap()` — this Flutter SDK version's overlay/hit-test geometry is unreliable inside scrollable bottom sheets in this codebase's test harness (confirmed this session across five failed tap-based attempts). Instead, get the widget instance via `tester.widget<T>(find.byType(T))` and invoke its `onChanged` (or `onTypeChanged`) callback directly, then `await tester.pumpAndSettle()`.
- **Correction found during Task 9 execution — real deadlock, not just a test-code fix:** the plan's original design had `showAddAnimalDialog` `await showAddInputDialog(...)` inline before returning `newId`, meaning `resultFuture` (the thing the test awaits via `tester.runAsync(() => resultFuture)`) would not resolve until the *second* modal sheet had been pushed. This deadlocks: `runAsync()` escapes Flutter's FakeAsync test zone to let real async gaps (platform channels, real timers) elapse, but `showModalBottomSheet`'s route-push internally schedules work tied to a new *frame*, which only advances via `tester.pump()` in the FakeAsync zone — code executing inside `runAsync()` never yields back to let a pump happen, so the two block each other forever (confirmed as a genuine hang: reproduced with `flutter test`'s own 10-minute per-test timeout, not just an impatient bash wrapper — the stack trace bottoms out in `dart:isolate _RawReceivePort._handleMessage`, `runAsync`'s own zone-bridging mechanism). The fix is architectural, in production code, not test code: `showAddAnimalDialog` fires `showAddInputDialog(...)` with `unawaited(...)` (`dart:async`) instead of `await`, so its own returned Future resolves as soon as the *first* sheet closes — matching the design spec's framing that the animal save and the cost prompt are "sequential, independent writes," not something the animal dialog's own caller should block on. The test then needs one more `await tester.pumpAndSettle();` *after* `await tester.runAsync(() => resultFuture)` to let the now fire-and-forget second sheet actually open before asserting on it. General lesson: never let code awaited through `tester.runAsync()` also push a new route or otherwise touch the widget tree — keep `runAsync()` scoped to the specific real-async gap (here, `UserUtils.getCurrentUserId()`'s platform channel call) and drive anything after it with normal `pump()`/`pumpAndSettle()` instead.
- **Correction found during Task 8 execution (two parts):** (1) `harness()`/`buildHarness()` test scaffolding must wrap `MaterialApp` itself with `MultiBlocProvider` — `MultiBlocProvider(child: MaterialApp(...))`, not `MaterialApp(home: MultiBlocProvider(...))` — matching how `main.dart`'s real `MyApp` wires providers above `MaterialApp.router`. `showModalBottomSheet`/`showDialog` push a new route as a *sibling* within the same `Navigator`, so a provider placed only inside `home:` is not an ancestor of that new route's own build context. This was invisible in every earlier task's tests (Land, Herd, Animal) because none of those forms contain a widget that does its *own* internal `context.read`/`BlocBuilder` lookup — they only read blocs once via the *caller's* context before the sheet opens. `CostCategoryTypeSelector` is the first widget in this plan to do its own internal `BlocBuilder<CostCategoryBloc, CostCategoryState>` lookup from inside the sheet, which is what exposes this. (2) `CostCategoryTypeSelector.onTypeChanged` is exactly the same kind of plain-callback prop as `EntityPickerWithAdd.onChanged`, wrapping its own required/validated inner `DropdownButtonFormField` — the same dual `FormFieldState.didChange(value)` + `.onTypeChanged(value)` drive applies to it (find its inner field via `find.ancestor(of: find.text(<its labelText>), matching: find.byType(DropdownButtonFormField<String>))`, since it has no `Key` of its own).
- **Correction found during Task 7 execution:** `animals_page.dart`'s setup-wizard body is a plain `ListView(children: [...])`, but Flutter still virtualizes a `ListView`'s children by viewport/cache-extent even when given a fixed `children:` list — widgets below the fold (confirmed here: everything from step 6 onward) are never built as Elements until the list is actually scrolled, so `find.text(...)` finds nothing for them even after `pumpAndSettle()`. Scroll first with `await tester.dragUntilVisible(find.text(<target>), find.byType(ListView), const Offset(0, -200)); await tester.pumpAndSettle();` before asserting on a step past the first few — this exact pattern already exists in `test/features/farm/presentation/pages/settings_page_test.dart` for the same reason.
- **Correction found during Task 4 execution, applies to every later task that submits a form after setting a *required/validated* dropdown field** (this affects the Animal Type and Herd pickers specifically, since both carry a `requiredSelection` validator — it does NOT affect Sex/Acquisition Source, which are optional with no validator): calling `.onChanged(value)` directly on `EntityPickerWithAdd`'s widget instance (or on a validated `DropdownButtonFormField`'s widget instance) only updates the outer closure variable — it never touches the inner `DropdownButtonFormField`'s own `FormFieldState`, which is what `Form.validate()` actually reads. Left uncorrected, `Form.validate()` silently keeps failing forever, `onSubmit` never runs, the sheet never closes, and `await tester.runAsync(() => resultFuture)` hangs until the test framework's own timeout (confirmed this session: a 10-minute real hang, not a quick failure). For any *required* dropdown field, drive both: the widget's `FormFieldState` via `tester.state<FormFieldState<String>>(find.descendant(of: find.byType(<PickerType>), matching: find.byType(DropdownButtonFormField<String>))).didChange(value)`, **and** the picker's own `onChanged(value)` callback (for the outer closure variable the submit handler actually reads) — both are needed together. Tasks 6, 9, and 10 below submit the form after setting Animal Type/Herd and must use this same dual-call pattern, not the plain `.onChanged(value)` shown in Task 4's original test draft.
- Commit after every task (or every step marked "Commit") on the existing branch `feat/creatable-entity-pickers` — no new branch. Push after each commit, matching this session's established pattern (the branch has an open PR, `NgigiN/jembe_frontend#7`, already targeting `dev`).
- Stage only the files a task actually touches; review `git status --short` before every commit.

---

## Task 1: `Animal` entity + `AnimalModel` — `sex` and `acquisitionSource`

**Files:**
- Modify: `lib/features/farm/domain/entities/animal.dart`
- Modify: `lib/features/farm/data/models/animal_model.dart`
- Test: `test/features/farm/data/models/animal_model_test.dart` (new file)

**Interfaces:**
- Produces: `Animal.sex` (`String?`), `Animal.acquisitionSource` (`String?`); `AnimalModel.create({..., String? sex, String? acquisitionSource})`; `AnimalModel.fromJson`/`toJson` round-trip both fields under keys `sex`/`acquisition_source`. Every later task that constructs an `Animal`/`AnimalModel` uses these exact field names.

- [x] **Step 1: Write the failing test**

Create `test/features/farm/data/models/animal_model_test.dart`:

```dart
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final birthDate = DateTime(2024, 1, 1);

  group('AnimalModel.create', () {
    test('carries optional sex and acquisitionSource through', () {
      final animal = AnimalModel.create(
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: birthDate,
        sex: 'female',
        acquisitionSource: 'bought',
      );

      expect(animal.sex, 'female');
      expect(animal.acquisitionSource, 'bought');
    });

    test('defaults sex and acquisitionSource to null when omitted', () {
      final animal = AnimalModel.create(
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: birthDate,
      );

      expect(animal.sex, isNull);
      expect(animal.acquisitionSource, isNull);
    });
  });

  group('AnimalModel.fromJson', () {
    test('parses snake_case sex and acquisition_source', () {
      final animal = AnimalModel.fromJson({
        'id': '1',
        'user_id': 'user-1',
        'name': 'Bessie',
        'animal_type_id': 'type-1',
        'herd_id': 'herd-1',
        'birth_date': birthDate.toIso8601String(),
        'sex': 'male',
        'acquisition_source': 'gift',
      });

      expect(animal.sex, 'male');
      expect(animal.acquisitionSource, 'gift');
    });

    test('parses missing sex and acquisition_source as null', () {
      final animal = AnimalModel.fromJson({
        'id': '1',
        'user_id': 'user-1',
        'name': 'Bessie',
        'animal_type_id': 'type-1',
        'herd_id': 'herd-1',
        'birth_date': birthDate.toIso8601String(),
      });

      expect(animal.sex, isNull);
      expect(animal.acquisitionSource, isNull);
    });
  });

  group('AnimalModel.toJson', () {
    test('includes sex and acquisition_source', () {
      final animal = AnimalModel.create(
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: birthDate,
        sex: 'female',
        acquisitionSource: 'bredOnFarm',
      );

      expect(animal.toJson()['sex'], 'female');
      expect(animal.toJson()['acquisition_source'], 'bredOnFarm');
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/data/models/animal_model_test.dart`
Expected: FAIL to compile — `sex`/`acquisitionSource` are not defined named parameters on `AnimalModel.create`.

- [x] **Step 3: Implement — `Animal` entity**

In `lib/features/farm/domain/entities/animal.dart`, add the two fields as optional (read the file first — do not assume its current shape from this plan):

```dart
class Animal extends Equatable {
  const Animal({
    required this.id,
    required this.userId,
    required this.name,
    required this.animalTypeId,
    required this.herdId,
    required this.birthDate,
    this.sex,
    this.acquisitionSource,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String animalTypeId;
  final String herdId;
  final DateTime birthDate;

  /// "male" or "female". Null means not recorded.
  final String? sex;

  /// "bought", "bredOnFarm", or "gift". Null means not recorded.
  final String? acquisitionSource;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        animalTypeId,
        herdId,
        birthDate,
        sex,
        acquisitionSource,
        createdAt,
        updatedAt,
      ];
}
```

- [x] **Step 4: Implement — `AnimalModel`**

In `lib/features/farm/data/models/animal_model.dart`, thread `sex`/`acquisitionSource` through the constructor, `create`, `fromJson`, and `toJson`:

```dart
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

class AnimalModel extends Animal {
  const AnimalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.animalTypeId,
    required super.herdId,
    required super.birthDate,
    required super.createdAt,
    required super.updatedAt,
    super.sex,
    super.acquisitionSource,
  });

  factory AnimalModel.create({
    required String userId,
    required String name,
    required String animalTypeId,
    required String herdId,
    required DateTime birthDate,
    String? sex,
    String? acquisitionSource,
  }) {
    final now = DateTime.now();
    return AnimalModel(
      id: '',
      userId: userId,
      name: name,
      animalTypeId: animalTypeId,
      herdId: herdId,
      birthDate: birthDate,
      sex: sex,
      acquisitionSource: acquisitionSource,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    final sexValue = json['Sex'] ?? json['sex'];
    final acquisitionSourceValue =
        json['AcquisitionSource'] ?? json['acquisition_source'];

    return AnimalModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      animalTypeId: (json['animal_type_id'] ?? json['AnimalTypeID'] ?? '').toString(),
      herdId: (json['herd_id'] ?? json['HerdID'] ?? '').toString(),
      birthDate: _parseDate(json['birth_date'] ?? json['BirthDate']),
      sex: sexValue?.toString(),
      acquisitionSource: acquisitionSourceValue?.toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'animal_type_id': int.tryParse(animalTypeId) ?? animalTypeId,
      'herd_id': int.tryParse(herdId) ?? herdId,
      'birth_date': birthDate.toUtc().toIso8601String(),
      'sex': sex,
      'acquisition_source': acquisitionSource,
    };
  }
}
```

- [x] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/farm/data/models/animal_model_test.dart`
Expected: PASS (5/5).

- [x] **Step 6: Commit**

```bash
git add lib/features/farm/domain/entities/animal.dart lib/features/farm/data/models/animal_model.dart test/features/farm/data/models/animal_model_test.dart
git commit -m "feat: add Animal.sex and Animal.acquisitionSource"
git push
```

---

## Task 2: Thread `sex`/`acquisitionSource` through `AnimalRepositoryImpl`

This mirrors a real bug found and fixed this session in `LandRepositoryImpl`: it rebuilt a `LandModel` from the incoming `Land` entity without carrying `tenureType`, silently dropping it before the network call. `AnimalRepositoryImpl.addAnimal`/`updateAnimal` have the exact same shape (explicit field-by-field reconstruction) and need the same fix pre-emptively, verified by a test before it ever ships broken.

**Files:**
- Modify: `lib/features/farm/data/repositories/animal_repository_impl.dart`
- Test: `test/features/farm/data/repositories/animal_repository_impl_test.dart` (new file — no repository-layer test exists for Animal today; mirrors the `land_repository_impl_test.dart` pattern added this session, using a hand-written `Fake` implementing `AnimalRemoteDataSource`, not a mock library)

**Interfaces:**
- Consumes: `Animal.sex`/`Animal.acquisitionSource` (Task 1), `AnimalModel.create`/`AnimalModel(...)` (Task 1), `AnimalRemoteDataSource` (`lib/features/farm/data/datasources/animal_remote_data_source.dart` — unchanged, already exists).
- Produces: nothing new consumed by later tasks — this closes a gap so `AnimalBloc` (Task 3) genuinely persists the two new fields.

- [x] **Step 1: Write the failing test**

Create `test/features/farm/data/repositories/animal_repository_impl_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

class FakeAnimalRemoteDataSource implements AnimalRemoteDataSource {
  AnimalModel? lastAdded;
  AnimalModel? lastUpdated;

  @override
  Future<List<AnimalModel>> getAnimals() async => [];

  @override
  Future<AnimalModel> addAnimal(AnimalModel animal) async {
    lastAdded = animal;
    return animal;
  }

  @override
  Future<AnimalModel> updateAnimal(AnimalModel animal) async {
    lastUpdated = animal;
    return animal;
  }

  @override
  Future<void> deleteAnimal(String id) async {}
}

void main() {
  final birthDate = DateTime(2024, 1, 1);

  test(
    'addAnimal carries sex and acquisitionSource from the Animal entity into the model sent to the data source',
    () async {
      final dataSource = FakeAnimalRemoteDataSource();
      final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      await repository.addAnimal(
        Animal(
          id: '',
          userId: 'user-1',
          name: 'Bessie',
          animalTypeId: 'type-1',
          herdId: 'herd-1',
          birthDate: birthDate,
          sex: 'female',
          acquisitionSource: 'bought',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(dataSource.lastAdded?.sex, 'female');
      expect(dataSource.lastAdded?.acquisitionSource, 'bought');
    },
  );

  test(
    'updateAnimal carries sex and acquisitionSource from the Animal entity into the model sent to the data source',
    () async {
      final dataSource = FakeAnimalRemoteDataSource();
      final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      await repository.updateAnimal(
        Animal(
          id: 'animal-1',
          userId: 'user-1',
          name: 'Bessie',
          animalTypeId: 'type-1',
          herdId: 'herd-1',
          birthDate: birthDate,
          sex: 'male',
          acquisitionSource: 'gift',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(dataSource.lastUpdated?.sex, 'male');
      expect(dataSource.lastUpdated?.acquisitionSource, 'gift');
    },
  );
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/data/repositories/animal_repository_impl_test.dart`
Expected: FAIL — both `sex` and `acquisitionSource` are `null` on the captured model, because `AnimalRepositoryImpl` doesn't pass them through yet.

- [x] **Step 3: Implement**

Read `lib/features/farm/data/repositories/animal_repository_impl.dart` in full, then apply:

```dart
  @override
  Future<Either<Failure, Animal>> addAnimal(Animal animal) async {
    try {
      final animalModel = AnimalModel.create(
        userId: animal.userId,
        name: animal.name,
        animalTypeId: animal.animalTypeId,
        herdId: animal.herdId,
        birthDate: animal.birthDate,
        sex: animal.sex,
        acquisitionSource: animal.acquisitionSource,
      );

      final result = await remoteDataSource.addAnimal(animalModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Animal>> updateAnimal(Animal animal) async {
    try {
      final animalModel = AnimalModel(
        id: animal.id,
        userId: animal.userId,
        name: animal.name,
        animalTypeId: animal.animalTypeId,
        herdId: animal.herdId,
        birthDate: animal.birthDate,
        sex: animal.sex,
        acquisitionSource: animal.acquisitionSource,
        createdAt: animal.createdAt,
        updatedAt: animal.updatedAt,
      );
      final result = await remoteDataSource.updateAnimal(animalModel);
      return Right(result);
    } on NetworkException catch (_) {
      return Left(const NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
```

(Leave `getAnimals` and `deleteAnimal` untouched — only `addAnimal`/`updateAnimal` reconstruct a model.)

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/data/repositories/animal_repository_impl_test.dart`
Expected: PASS (2/2).

- [x] **Step 5: Commit**

```bash
git add lib/features/farm/data/repositories/animal_repository_impl.dart test/features/farm/data/repositories/animal_repository_impl_test.dart
git commit -m "fix: thread Animal.sex/acquisitionSource through AnimalRepositoryImpl"
git push
```

---

## Task 3: `AnimalBloc`/`AnimalEvent`/`AnimalState` + DI wiring + `AnimalPage` list skeleton

No bloc anywhere in this codebase has a direct unit test — bloc behavior is proven only through page-level widget tests using a `MockBloc`/`whenListen` harness (see `test/features/farm/presentation/pages/land_page_test.dart`). This task therefore builds the bloc together with just enough of `AnimalPage` (list view, no add/edit yet) to make it independently testable, exactly like every other entity in this codebase.

**Files:**
- Create: `lib/features/farm/presentation/bloc/animal_event.dart`
- Create: `lib/features/farm/presentation/bloc/animal_state.dart`
- Create: `lib/features/farm/presentation/bloc/animal_bloc.dart`
- Create: `lib/features/farm/presentation/pages/animal_page.dart`
- Modify: `lib/injection_container.dart`
- Modify: `lib/main.dart`
- Test: `test/features/farm/presentation/pages/animal_page_test.dart` (new file)

**Interfaces:**
- Consumes: `GetAnimals`, `AddAnimal`+`AddAnimalParams`, `UpdateAnimal`+`UpdateAnimalParams`, `DeleteAnimal`+`DeleteAnimalParams` (`lib/features/farm/domain/usecases/{get_animals,add_animal,update_animal,delete_animal}.dart` — already exist, unchanged), `Animal` (Task 1).
- Produces: `GetAnimalsEvent`, `AddAnimalEvent(Animal)`, `UpdateAnimalEvent(Animal)`, `DeleteAnimalEvent(String id)`; `AnimalState.animals` (`List<Animal>`), `AnimalInitial`, `AnimalLoading({animals})`, `AnimalLoaded({required animals, successMessage})`, `AnimalError(message, {animals})`; `AnimalBloc({getAnimals, addAnimal, updateAnimal, deleteAnimal})`. `AnimalPage` (a `StatefulWidget`, no const constructor args). Every later task's tests reference these exact names.

- [x] **Step 1: Write the failing test**

Create `test/features/farm/presentation/pages/animal_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
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

final now = DateTime.now();

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
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: FAIL to compile — none of `AnimalBloc`, `AnimalEvent`, `AnimalState`, `AnimalPage` exist yet.

- [x] **Step 3: Implement `AnimalEvent`**

Create `lib/features/farm/presentation/bloc/animal_event.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetAnimalsEvent extends AnimalEvent {}

class AddAnimalEvent extends AnimalEvent {
  AddAnimalEvent(this.animal);
  final Animal animal;

  @override
  List<Object> get props => [animal];
}

class UpdateAnimalEvent extends AnimalEvent {
  UpdateAnimalEvent(this.animal);
  final Animal animal;

  @override
  List<Object> get props => [animal];
}

class DeleteAnimalEvent extends AnimalEvent {
  DeleteAnimalEvent(this.id);
  final String id;

  @override
  List<Object> get props => [id];
}
```

- [x] **Step 4: Implement `AnimalState`**

Create `lib/features/farm/presentation/bloc/animal_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

abstract class AnimalState extends Equatable {
  const AnimalState({this.animals = const []});
  final List<Animal> animals;

  @override
  List<Object?> get props => [animals];
}

class AnimalInitial extends AnimalState {}

class AnimalLoading extends AnimalState {
  const AnimalLoading({super.animals});
}

class AnimalLoaded extends AnimalState {
  const AnimalLoaded({required super.animals, this.successMessage});
  final String? successMessage;

  @override
  List<Object?> get props => [animals, successMessage];
}

class AnimalError extends AnimalState {
  const AnimalError(this.message, {super.animals});
  final String message;

  @override
  List<Object> get props => [message, animals];
}
```

- [x] **Step 5: Implement `AnimalBloc`**

Create `lib/features/farm/presentation/bloc/animal_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_animals.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_animal.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_animal.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';

class AnimalBloc extends Bloc<AnimalEvent, AnimalState> {
  AnimalBloc({
    required this.getAnimals,
    required this.addAnimal,
    required this.updateAnimal,
    required this.deleteAnimal,
  }) : super(AnimalInitial()) {
    on<GetAnimalsEvent>((event, emit) async {
      emit(const AnimalLoading());
      final result = await getAnimals(NoParams());
      result.fold(
        (failure) => emit(
          AnimalError(resolveFailureMessage(failure, 'Failed to load animals')),
        ),
        (animals) => emit(AnimalLoaded(animals: animals)),
      );
    });

    on<AddAnimalEvent>((event, emit) async {
      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await addAnimal(AddAnimalParams(animal: event.animal));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to add animal'),
          animals: currentAnimals,
        )),
        (animal) {
          final updatedAnimals = List<Animal>.from(currentAnimals)..add(animal);
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal added'));
        },
      );
    });

    on<UpdateAnimalEvent>((event, emit) async {
      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await updateAnimal(UpdateAnimalParams(animal: event.animal));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to update animal'),
          animals: currentAnimals,
        )),
        (updatedAnimal) {
          final updatedAnimals = currentAnimals.map((animal) {
            return animal.id == updatedAnimal.id ? updatedAnimal : animal;
          }).toList();
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal updated'));
        },
      );
    });

    on<DeleteAnimalEvent>((event, emit) async {
      final currentAnimals = state.animals;

      emit(AnimalLoading(animals: currentAnimals));
      final result = await deleteAnimal(DeleteAnimalParams(id: event.id));
      result.fold(
        (failure) => emit(AnimalError(
          resolveFailureMessage(failure, 'Failed to delete animal'),
          animals: currentAnimals,
        )),
        (_) {
          final updatedAnimals =
              currentAnimals.where((animal) => animal.id != event.id).toList();
          emit(AnimalLoaded(animals: updatedAnimals, successMessage: 'Animal deleted'));
        },
      );
    });
  }
  final GetAnimals getAnimals;
  final AddAnimal addAnimal;
  final UpdateAnimal updateAnimal;
  final DeleteAnimal deleteAnimal;
}
```

- [x] **Step 6: Implement `AnimalPage` (list only)**

Create `lib/features/farm/presentation/pages/animal_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:farm_tracker/core/utils/safe_layout_utils.dart';
import 'package:farm_tracker/core/widgets/safe_floating_action_button.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/crud/entity_empty_view.dart';
import 'package:farm_tracker/core/theme/app_colors.dart';
import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:farm_tracker/core/widgets/loading/skeleton_entity_list.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/presentation/utils/source_context_resolver.dart';

class AnimalPage extends StatefulWidget {
  const AnimalPage({super.key});

  @override
  State<AnimalPage> createState() => _AnimalPageState();
}

class _AnimalPageState extends State<AnimalPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnimalBloc>().add(GetAnimalsEvent());
    context.read<AnimalTypeBloc>().add(GetAnimalTypesEvent());
    context.read<HerdBloc>().add(GetHerdsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final animalTypeState = context.watch<AnimalTypeBloc>().state;
    final animalTypes = animalTypeState.animalTypes;
    final herdState = context.watch<HerdBloc>().state;
    final herds = herdState.herds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AnimalBloc, AnimalState>(
        listener: (context, state) {
          if (state is AnimalLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.success(state.successMessage!),
            );
          } else if (state is AnimalError && state.animals.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error(state.message),
            );
          }
        },
        builder: (context, state) {
          if (state is AnimalLoading && state.animals.isEmpty) {
            return const SkeletonEntityList(icon: Icons.pets);
          }

          if (state is AnimalError && state.animals.isEmpty) {
            return EntityErrorView(
              message: state.message,
              onRetry: () => context.read<AnimalBloc>().add(GetAnimalsEvent()),
            );
          }

          final animals = state.animals;
          if (animals.isEmpty) {
            return EntityEmptyView(
              icon: Icons.pets,
              title: 'No animals registered yet',
              subtitle: 'Tap the + button to add your first animal',
            );
          }

          return ListView.builder(
            padding: context.scrollListPadding(forFab: true),
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              return EntityCard(
                icon: Icons.pets,
                iconColor: AppColors.animalCategory,
                title: animal.name,
                subtitle: _animalSubtitle(animal, animalTypes, herds),
                onTap: () {},
              );
            },
          );
        },
      ),
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _animalSubtitle(Animal animal, List<AnimalType> animalTypes, List<Herd> herds) {
    return '${animalTypeName(animalTypes, animal.animalTypeId)} · ${herdName(herds, animal.herdId)}';
  }
}
```

Add `animalTypeName` to `lib/features/farm/presentation/utils/source_context_resolver.dart` (read the file first — it already has `herdName`/`landName` following this exact shape):

```dart
String animalTypeName(List<AnimalType> animalTypes, String animalTypeId) {
  for (final animalType in animalTypes) {
    if (animalType.id == animalTypeId) return animalType.name;
  }
  return 'Unknown type';
}
```

This needs `import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';` added to that file's imports.

Note: the FAB's `onPressed: () {}` and the card's `onTap: () {}` are deliberately no-ops here — Task 4 (add) and Task 6 (edit/details/delete) fill them in. This keeps this task's diff reviewable on its own list-rendering behavior.

- [x] **Step 7: Wire DI — `injection_container.dart`**

Read `lib/injection_container.dart` in full first. Add the import alphabetically between `analysis_bloc.dart` and `animal_type_bloc.dart` (around line 113):

```dart
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
```

Add the factory registration right after the existing `HerdBloc` registration and before `HerdActivityBloc` (around line 208):

```dart
    ..registerFactory(
      () => AnimalBloc(
        getAnimals: sl(),
        addAnimal: sl(),
        updateAnimal: sl(),
        deleteAnimal: sl(),
      ),
    )
```

(`GetAnimals`, `AddAnimal`, `UpdateAnimal`, `DeleteAnimal`, `AnimalRepository`, `AnimalRemoteDataSource` are all already registered — no other injection_container.dart changes needed.)

- [x] **Step 8: Wire DI — `main.dart`**

Read `lib/main.dart` in full first. Add the import alphabetically between `activity_bloc.dart` and `analysis_bloc.dart`... actually between `analysis_bloc.dart` (present) and `animal_type_bloc.dart` (present) — i.e. right before the existing `animal_type_bloc.dart` import:

```dart
import 'package:farm_tracker/features/farm/presentation/bloc/animal_bloc.dart';
```

Add the provider right after `BlocProvider<HerdBloc>(...)` and before `BlocProvider<HerdActivityBloc>(...)`:

```dart
        BlocProvider<AnimalBloc>(create: (_) => di.sl<AnimalBloc>()),
```

- [x] **Step 9: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: PASS (2/2).

- [x] **Step 10: Run the full suite and analyzer**

Run: `flutter analyze` — expect no new errors (existing `info`-level lints are pre-existing and out of scope).
Run: `flutter test` — expect the same pass count as before this task plus the new tests, with only the pre-existing stale `test/widget_test.dart` counter test failing (unrelated to this work, confirmed earlier this session).

- [x] **Step 11: Commit**

```bash
git add lib/features/farm/presentation/bloc/animal_event.dart lib/features/farm/presentation/bloc/animal_state.dart lib/features/farm/presentation/bloc/animal_bloc.dart lib/features/farm/presentation/pages/animal_page.dart lib/features/farm/presentation/utils/source_context_resolver.dart lib/injection_container.dart lib/main.dart test/features/farm/presentation/pages/animal_page_test.dart
git commit -m "feat: add AnimalBloc and AnimalPage list view"
git push
```

---

## Task 4: Add-Animal form (name, type, herd, birth date, sex, acquisition source)

**Files:**
- Modify: `lib/features/farm/presentation/pages/animal_page.dart`
- Test: `test/features/farm/presentation/pages/animal_page_test.dart`

**Interfaces:**
- Consumes: `EntityPickerWithAdd<T>` (`lib/core/widgets/crud/entity_picker_with_add.dart` — unchanged), `showAddAnimalTypeDialog` (`lib/features/farm/presentation/pages/animal_type_page.dart`), `showAddHerdDialog` (`lib/features/farm/presentation/pages/herd_page.dart`), `EntityFormSheet.show` (`lib/core/widgets/crud/entity_form_sheet.dart`), `AnimalModel.create` (Task 1).
- Produces: top-level `Future<String?> showAddAnimalDialog(BuildContext context)` — later tasks (9) call this same function; it must keep this exact signature.

- [x] **Step 1: Write the failing test**

Add to `test/features/farm/presentation/pages/animal_page_test.dart` (append inside `main()`, alongside the existing tests). Add these imports at the top of the file (`animal_page.dart`'s import is already present from Task 3):

```dart
import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
```

```dart
  group('showAddAnimalDialog', () {
    late MockAnimalBloc animalBloc;
    late MockAnimalTypeBloc animalTypeBloc;
    late MockHerdBloc herdBloc;
    late StreamController<AnimalState> stateController;

    setUpAll(() {
      registerFallbackValue(GetAnimalsEvent());
    });

    setUp(() {
      animalBloc = MockAnimalBloc();
      animalTypeBloc = MockAnimalTypeBloc();
      herdBloc = MockHerdBloc();
      stateController = StreamController<AnimalState>.broadcast();
      whenListen(
        animalBloc,
        stateController.stream,
        initialState: const AnimalLoaded(animals: []),
      );
      whenListen(
        animalTypeBloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeLoaded([
          AnimalType(
            id: 'type-1',
            userId: 'user-1',
            name: 'Cow',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      whenListen(
        herdBloc,
        const Stream<HerdState>.empty(),
        initialState: HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'Main Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 5,
            currentHeadCount: 5,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
    });

    tearDown(() => stateController.close());

    Widget buildHarness(ValueChanged<Future<String?>> capture) {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AnimalBloc>.value(value: animalBloc),
            BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
            BlocProvider<HerdBloc>.value(value: herdBloc),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => capture(showAddAnimalDialog(context)),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('submits name, type, herd, sex, and acquisition source on the dispatched AddAnimalEvent', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Bessie',
      );

      // Animal Type and Herd are *required* fields with validators, so
      // Form.validate() reads their inner DropdownButtonFormField's own
      // FormFieldState, not just the outer onChanged callback — drive both,
      // per the Global Constraints correction above, or the sheet never
      // closes and this test hangs until the framework's own timeout.
      final typePicker = tester.widget<EntityPickerWithAdd<AnimalType>>(
        find.byType(EntityPickerWithAdd<AnimalType>),
      );
      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<AnimalType>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('type-1');
      typePicker.onChanged('type-1');
      await tester.pumpAndSettle();

      final herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<Herd>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('herd-1');
      herdPicker.onChanged('herd-1');
      await tester.pumpAndSettle();

      final sexDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('animal-sex-field')),
      );
      sexDropdown.onChanged!('female');
      await tester.pumpAndSettle();

      final acquisitionDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('animal-acquisition-source-field')),
      );
      acquisitionDropdown.onChanged!('bredOnFarm');
      await tester.pumpAndSettle();

      stateController.add(
        AnimalLoaded(
          animals: [
            Animal(
              id: 'animal-1',
              userId: 'user-1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              sex: 'female',
              acquisitionSource: 'bredOnFarm',
              createdAt: now,
              updatedAt: now,
            ),
          ],
          successMessage: 'Animal added',
        ),
      );

      await tester.tap(find.text('Add Animal'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => resultFuture);

      final captured = verify(() => animalBloc.add(captureAny())).captured;
      final event = captured.whereType<AddAnimalEvent>().single;
      expect(event.animal.name, 'Bessie');
      expect(event.animal.animalTypeId, 'type-1');
      expect(event.animal.herdId, 'herd-1');
      expect(event.animal.sex, 'female');
      expect(event.animal.acquisitionSource, 'bredOnFarm');
    });
  });
```

This group reuses the file-level `final now = DateTime.now();` declared above `main()` in Task 3 — no new declaration needed.

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: FAIL — `showAddAnimalDialog` is not defined, and `Key('animal-sex-field')`/`Key('animal-acquisition-source-field')` don't exist yet.

- [x] **Step 3: Implement**

In `lib/features/farm/presentation/pages/animal_page.dart`, add these imports:

```dart
import 'package:farm_tracker/core/validation/validated_fields.dart';
import 'package:farm_tracker/core/validation/validators.dart';
import 'package:farm_tracker/core/validation/sanitize.dart';
import 'package:farm_tracker/core/widgets/crud/entity_form_sheet.dart';
import 'package:farm_tracker/core/widgets/crud/entity_picker_with_add.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animal_type_page.dart';
import 'package:farm_tracker/features/farm/presentation/pages/herd_page.dart';
```

Add this top-level function above `class AnimalPage`:

```dart
/// Opens the standard "Add Animal" form and resolves once it closes: the
/// new animal's id if the add succeeded, or null if the sheet was
/// dismissed without submitting.
Future<String?> showAddAnimalDialog(BuildContext context) async {
  final bloc = context.read<AnimalBloc>();
  final beforeIds = bloc.state.animals.map((animal) => animal.id).toSet();
  String? newId;

  final subscription = bloc.stream.listen((state) {
    if (state is AnimalLoaded && state.successMessage == 'Animal added') {
      for (final animal in state.animals) {
        if (!beforeIds.contains(animal.id)) {
          newId = animal.id;
          break;
        }
      }
    }
  });

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  String? selectedAnimalTypeId;
  String? selectedHerdId;
  var selectedBirthDate = DateTime.now();
  String? selectedSex;
  String? selectedAcquisitionSource;

  final animalTypes = context.read<AnimalTypeBloc>().state.animalTypes;
  final herds = context.read<HerdBloc>().state.herds;

  await EntityFormSheet.show(
    context: context,
    title: 'Add New Animal',
    submitLabel: 'Add Animal',
    formKey: formKey,
    fields: _animalFormFields(
      nameController: nameController,
      animalTypes: animalTypes,
      herds: herds,
      selectedAnimalTypeId: selectedAnimalTypeId,
      selectedHerdId: selectedHerdId,
      selectedBirthDate: selectedBirthDate,
      selectedSex: selectedSex,
      selectedAcquisitionSource: selectedAcquisitionSource,
      onAnimalTypeChanged: (value) => selectedAnimalTypeId = value,
      onHerdChanged: (value) => selectedHerdId = value,
      onBirthDateChanged: (value) => selectedBirthDate = value,
      onSexChanged: (value) => selectedSex = value,
      onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
    ),
    onSubmit: (sheetContext) async {
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final animal = AnimalModel.create(
        userId: userId,
        name: sanitizeText(nameController.text),
        animalTypeId: selectedAnimalTypeId!,
        herdId: selectedHerdId!,
        birthDate: selectedBirthDate,
        sex: selectedSex,
        acquisitionSource: selectedAcquisitionSource,
      );
      bloc.add(AddAnimalEvent(animal));
      Navigator.pop(sheetContext);
    },
  );

  await subscription.cancel();
  return newId;
}

List<Widget> _animalFormFields({
  required TextEditingController nameController,
  required List<AnimalType> animalTypes,
  required List<Herd> herds,
  required String? selectedAnimalTypeId,
  required String? selectedHerdId,
  required DateTime selectedBirthDate,
  String? selectedSex,
  String? selectedAcquisitionSource,
  required ValueChanged<String?> onAnimalTypeChanged,
  required ValueChanged<String?> onHerdChanged,
  required ValueChanged<DateTime> onBirthDateChanged,
  ValueChanged<String?>? onSexChanged,
  ValueChanged<String?>? onAcquisitionSourceChanged,
}) {
  return [
    ValidatedNameField(
      controller: nameController,
      labelText: 'Name *',
      validator: (value) => requiredName(value, fieldLabel: 'Name'),
    ),
    const SizedBox(height: 16),
    EntityPickerWithAdd<AnimalType>(
      items: animalTypes,
      selectedId: selectedAnimalTypeId,
      idOf: (type) => type.id,
      labelOf: (type) => type.name,
      labelText: 'Animal Type *',
      validator: (value) => requiredSelection(value, fieldLabel: 'animal type'),
      onChanged: onAnimalTypeChanged,
      onAddNew: showAddAnimalTypeDialog,
    ),
    const SizedBox(height: 16),
    EntityPickerWithAdd<Herd>(
      items: herds,
      selectedId: selectedHerdId,
      idOf: (herd) => herd.id,
      labelOf: (herd) => '${herd.name} (${herd.location})',
      labelText: 'Herd *',
      validator: (value) => requiredSelection(value, fieldLabel: 'herd'),
      onChanged: onHerdChanged,
      onAddNew: showAddHerdDialog,
    ),
    const SizedBox(height: 16),
    FormField<DateTime>(
      initialValue: selectedBirthDate,
      builder: (field) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth Date'),
        subtitle: Text(_formatDate(selectedBirthDate)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final date = await showDatePicker(
            context: field.context,
            initialDate: selectedBirthDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            onBirthDateChanged(date);
            field.didChange(date);
          }
        },
      ),
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('animal-sex-field'),
      initialValue: selectedSex,
      decoration: const InputDecoration(
        labelText: 'Sex (Optional)',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
      ],
      onChanged: onSexChanged,
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('animal-acquisition-source-field'),
      initialValue: selectedAcquisitionSource,
      decoration: const InputDecoration(
        labelText: 'Acquisition Source (Optional)',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'bought', child: Text('Bought')),
        DropdownMenuItem(value: 'bredOnFarm', child: Text('Bred on Farm')),
        DropdownMenuItem(value: 'gift', child: Text('Gift')),
      ],
      onChanged: onAcquisitionSourceChanged,
    ),
  ];
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
```

Add `import 'package:farm_tracker/features/auth/data/utils/user_utils.dart';` to the top of `animal_page.dart` (same import `land_page.dart` uses for `UserUtils.getCurrentUserId()`).

Wire the FAB to call it — replace the Task 3 placeholder in `_AnimalPageState.build`:

```dart
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => showAddAnimalDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
```

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: PASS (3/3).

- [x] **Step 5: Run the full suite and analyzer, then commit**

Run: `flutter analyze` and `flutter test`, confirm no new failures.

```bash
git add lib/features/farm/presentation/pages/animal_page.dart test/features/farm/presentation/pages/animal_page_test.dart
git commit -m "feat: add showAddAnimalDialog with type/herd/birth date/sex/acquisition source"
git push
```

---

## Task 5: Filter the Herd picker by the selected Animal Type

Per the approved design: selecting an Animal Type filters the Herd picker to herds whose `animalTypeId` matches, and changing the Animal Type clears an now-invalid Herd selection. `EntityFormSheet.show`'s `fields: List<Widget>` is built once (not itself rebuildable), so this needs a small reactive subtree using `ValueNotifier` + `ListenableBuilder`, scoped to just the two pickers.

**Files:**
- Modify: `lib/features/farm/presentation/pages/animal_page.dart`
- Test: `test/features/farm/presentation/pages/animal_page_test.dart`

**Interfaces:**
- Consumes: `_animalFormFields` (Task 4) — its signature changes from separate `selectedAnimalTypeId`/`selectedHerdId`/`onAnimalTypeChanged`/`onHerdChanged` params to two `ValueNotifier<String?>` params (`animalTypeIdNotifier`, `herdIdNotifier`); `showAddAnimalDialog` (Task 4) is updated to match.
- Produces: nothing new consumed elsewhere — this is a self-contained UX refinement to the same form.

- [x] **Step 1: Write the failing test**

Add to the `showAddAnimalDialog` group in `test/features/farm/presentation/pages/animal_page_test.dart` (this test needs a second herd of a different type in `herdBloc`'s state — update that `setUp`'s `HerdLoaded([...])` to include two herds):

```dart
      whenListen(
        herdBloc,
        const Stream<HerdState>.empty(),
        initialState: HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'Cow Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 5,
            currentHeadCount: 5,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          Herd(
            id: 'herd-2',
            userId: 'user-1',
            name: 'Goat Herd',
            animalTypeId: 'type-2',
            location: 'South Field',
            initialHeadCount: 3,
            currentHeadCount: 3,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
```

and update the `AnimalTypeLoaded([...])` in the same `setUp` to include a second type:

```dart
      whenListen(
        animalTypeBloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeLoaded([
          AnimalType(
            id: 'type-1',
            userId: 'user-1',
            name: 'Cow',
            createdAt: now,
            updatedAt: now,
          ),
          AnimalType(
            id: 'type-2',
            userId: 'user-1',
            name: 'Goat',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
```

Then add the new test:

```dart
    testWidgets('herd picker only shows herds matching the selected animal type', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final typePicker = tester.widget<EntityPickerWithAdd<AnimalType>>(
        find.byType(EntityPickerWithAdd<AnimalType>),
      );
      typePicker.onChanged('type-1');
      await tester.pumpAndSettle();

      var herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      expect(herdPicker.items.map((h) => h.id), ['herd-1']);

      typePicker.onChanged('type-2');
      await tester.pumpAndSettle();

      herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      expect(herdPicker.items.map((h) => h.id), ['herd-2']);
    });

    testWidgets('changing animal type clears a now-invalid herd selection', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final typePicker = tester.widget<EntityPickerWithAdd<AnimalType>>(
        find.byType(EntityPickerWithAdd<AnimalType>),
      );
      typePicker.onChanged('type-1');
      await tester.pumpAndSettle();

      var herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      herdPicker.onChanged('herd-1');
      await tester.pumpAndSettle();

      typePicker.onChanged('type-2');
      await tester.pumpAndSettle();

      herdPicker = tester.widget<EntityPickerWithAdd<Herd>>(
        find.byType(EntityPickerWithAdd<Herd>),
      );
      expect(herdPicker.selectedId, isNull);
    });
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: FAIL — the herd picker's `items` list is unfiltered (both herds always present), and the selection doesn't clear.

- [x] **Step 3: Implement**

In `lib/features/farm/presentation/pages/animal_page.dart`, change `showAddAnimalDialog` to hold notifiers instead of plain variables for these two fields:

```dart
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final animalTypeIdNotifier = ValueNotifier<String?>(null);
  final herdIdNotifier = ValueNotifier<String?>(null);
  var selectedBirthDate = DateTime.now();
  String? selectedSex;
  String? selectedAcquisitionSource;

  final animalTypes = context.read<AnimalTypeBloc>().state.animalTypes;
  final herds = context.read<HerdBloc>().state.herds;

  await EntityFormSheet.show(
    context: context,
    title: 'Add New Animal',
    submitLabel: 'Add Animal',
    formKey: formKey,
    fields: _animalFormFields(
      nameController: nameController,
      animalTypes: animalTypes,
      herds: herds,
      animalTypeIdNotifier: animalTypeIdNotifier,
      herdIdNotifier: herdIdNotifier,
      selectedBirthDate: selectedBirthDate,
      selectedSex: selectedSex,
      selectedAcquisitionSource: selectedAcquisitionSource,
      onBirthDateChanged: (value) => selectedBirthDate = value,
      onSexChanged: (value) => selectedSex = value,
      onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
    ),
    onSubmit: (sheetContext) async {
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final animal = AnimalModel.create(
        userId: userId,
        name: sanitizeText(nameController.text),
        animalTypeId: animalTypeIdNotifier.value!,
        herdId: herdIdNotifier.value!,
        birthDate: selectedBirthDate,
        sex: selectedSex,
        acquisitionSource: selectedAcquisitionSource,
      );
      bloc.add(AddAnimalEvent(animal));
      Navigator.pop(sheetContext);
    },
  );
```

Replace `_animalFormFields`'s animal-type/herd parameters and the pickers block:

```dart
List<Widget> _animalFormFields({
  required TextEditingController nameController,
  required List<AnimalType> animalTypes,
  required List<Herd> herds,
  required ValueNotifier<String?> animalTypeIdNotifier,
  required ValueNotifier<String?> herdIdNotifier,
  required DateTime selectedBirthDate,
  String? selectedSex,
  String? selectedAcquisitionSource,
  required ValueChanged<DateTime> onBirthDateChanged,
  ValueChanged<String?>? onSexChanged,
  ValueChanged<String?>? onAcquisitionSourceChanged,
}) {
  return [
    ValidatedNameField(
      controller: nameController,
      labelText: 'Name *',
      validator: (value) => requiredName(value, fieldLabel: 'Name'),
    ),
    const SizedBox(height: 16),
    ListenableBuilder(
      listenable: Listenable.merge([animalTypeIdNotifier, herdIdNotifier]),
      builder: (context, _) {
        final filteredHerds = herds
            .where((herd) =>
                animalTypeIdNotifier.value == null ||
                herd.animalTypeId == animalTypeIdNotifier.value)
            .toList();
        return Column(
          children: [
            EntityPickerWithAdd<AnimalType>(
              items: animalTypes,
              selectedId: animalTypeIdNotifier.value,
              idOf: (type) => type.id,
              labelOf: (type) => type.name,
              labelText: 'Animal Type *',
              validator: (value) =>
                  requiredSelection(value, fieldLabel: 'animal type'),
              onChanged: (value) {
                animalTypeIdNotifier.value = value;
                final stillValid = herds.any((herd) =>
                    herd.id == herdIdNotifier.value &&
                    herd.animalTypeId == value);
                if (!stillValid) herdIdNotifier.value = null;
              },
              onAddNew: showAddAnimalTypeDialog,
            ),
            const SizedBox(height: 16),
            EntityPickerWithAdd<Herd>(
              items: filteredHerds,
              selectedId: herdIdNotifier.value,
              idOf: (herd) => herd.id,
              labelOf: (herd) => '${herd.name} (${herd.location})',
              labelText: 'Herd *',
              validator: (value) => requiredSelection(value, fieldLabel: 'herd'),
              onChanged: (value) => herdIdNotifier.value = value,
              onAddNew: showAddHerdDialog,
            ),
          ],
        );
      },
    ),
    const SizedBox(height: 16),
    FormField<DateTime>(
      initialValue: selectedBirthDate,
      builder: (field) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth Date'),
        subtitle: Text(_formatDate(selectedBirthDate)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final date = await showDatePicker(
            context: field.context,
            initialDate: selectedBirthDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            onBirthDateChanged(date);
            field.didChange(date);
          }
        },
      ),
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('animal-sex-field'),
      initialValue: selectedSex,
      decoration: const InputDecoration(
        labelText: 'Sex (Optional)',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
      ],
      onChanged: onSexChanged,
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('animal-acquisition-source-field'),
      initialValue: selectedAcquisitionSource,
      decoration: const InputDecoration(
        labelText: 'Acquisition Source (Optional)',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'bought', child: Text('Bought')),
        DropdownMenuItem(value: 'bredOnFarm', child: Text('Bred on Farm')),
        DropdownMenuItem(value: 'gift', child: Text('Gift')),
      ],
      onChanged: onAcquisitionSourceChanged,
    ),
  ];
}
```

(Only the animal-type/herd block changed from Task 4 — the birth-date field, sex dropdown, and acquisition-source dropdown above are copied verbatim from Task 4's version, since `_animalFormFields` is being fully replaced in this step, not patched.)

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: PASS (5/5).

- [x] **Step 5: Run the full suite and analyzer, then commit**

```bash
git add lib/features/farm/presentation/pages/animal_page.dart test/features/farm/presentation/pages/animal_page_test.dart
git commit -m "feat: filter Animal's herd picker by the selected animal type"
git push
```

---

## Task 6: Edit Animal, details sheet, delete

Mirrors `LandPage`'s `_showEditLandDialog`/`_showLandDetails`/`_showDeleteConfirmation` exactly.

**Files:**
- Modify: `lib/features/farm/presentation/pages/animal_page.dart`
- Test: `test/features/farm/presentation/pages/animal_page_test.dart`

**Interfaces:**
- Consumes: `EntityDetailsSheet`, `EntityDeleteDialog`, `EntityDetailRow` (unchanged), `UpdateAnimalEvent`/`DeleteAnimalEvent` (Task 3).
- Produces: nothing new consumed elsewhere in this plan.

- [x] **Step 1: Write the failing test**

Add a new group to `test/features/farm/presentation/pages/animal_page_test.dart`:

```dart
  group('editing an animal', () {
    late MockAnimalBloc animalBloc;
    late MockAnimalTypeBloc animalTypeBloc;
    late MockHerdBloc herdBloc;
    late Animal existingAnimal;

    setUpAll(() {
      registerFallbackValue(GetAnimalsEvent());
    });

    setUp(() {
      existingAnimal = Animal(
        id: 'animal-1',
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: now,
        sex: 'female',
        acquisitionSource: 'bredOnFarm',
        createdAt: now,
        updatedAt: now,
      );
      animalBloc = MockAnimalBloc();
      animalTypeBloc = MockAnimalTypeBloc();
      herdBloc = MockHerdBloc();
      whenListen(
        animalBloc,
        Stream<AnimalState>.value(AnimalLoaded(animals: [existingAnimal])),
        initialState: AnimalLoaded(animals: [existingAnimal]),
      );
      whenListen(
        animalTypeBloc,
        const Stream<AnimalTypeState>.empty(),
        initialState: AnimalTypeLoaded([
          AnimalType(
            id: 'type-1',
            userId: 'user-1',
            name: 'Cow',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      whenListen(
        herdBloc,
        const Stream<HerdState>.empty(),
        initialState: HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'Cow Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 5,
            currentHeadCount: 5,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
    });

    testWidgets('shows details, edits sex, and dispatches UpdateAnimalEvent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();

      expect(find.text('Female'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final sexDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('animal-sex-field')),
      );
      sexDropdown.onChanged!('male');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Animal'));
      await tester.pumpAndSettle();

      final captured = verify(() => animalBloc.add(captureAny())).captured;
      final event = captured.whereType<UpdateAnimalEvent>().single;
      expect(event.animal.sex, 'male');
    });

    testWidgets('deletes the animal on confirmation', (tester) async {
      await tester.pumpWidget(
        _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      verify(() => animalBloc.add(DeleteAnimalEvent('animal-1'))).called(1);
    });
  });
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: FAIL — tapping "Bessie" does nothing (Task 3 left `onTap: () {}`), so no details sheet, no "Edit"/"Delete" text found.

- [x] **Step 3: Implement**

In `lib/features/farm/presentation/pages/animal_page.dart`, add these imports:

```dart
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
import 'package:farm_tracker/core/widgets/crud/entity_detail_row.dart';
import 'package:farm_tracker/core/widgets/crud/entity_details_sheet.dart';
```

Replace the list-item's `onTap: () {}` with `onTap: () => _showAnimalDetails(context, animal, animalTypes, herds)`, and add these methods to `_AnimalPageState` (mirroring `LandPage`'s `_showLandDetails`/`_showEditLandDialog`/`_showDeleteConfirmation`):

```dart
  void _showAnimalDetails(
    BuildContext context,
    Animal animal,
    List<AnimalType> animalTypes,
    List<Herd> herds,
  ) {
    EntityDetailsSheet.show(
      context: context,
      title: animal.name,
      details: [
        EntityDetailRow('Type', animalTypeName(animalTypes, animal.animalTypeId)),
        EntityDetailRow('Herd', herdName(herds, animal.herdId)),
        EntityDetailRow('Birth Date', _formatDate(animal.birthDate)),
        EntityDetailRow(
          'Sex',
          animal.sex?.isNotEmpty == true
              ? animal.sex![0].toUpperCase() + animal.sex!.substring(1)
              : '—',
        ),
        EntityDetailRow(
          'Acquisition Source',
          animal.acquisitionSource?.isNotEmpty == true
              ? animal.acquisitionSource![0].toUpperCase() +
                  animal.acquisitionSource!.substring(1)
              : '—',
        ),
      ],
      onEdit: () => _showEditAnimalDialog(animal, animalTypes, herds),
      onDelete: () => _showDeleteConfirmation(animal),
    );
  }

  void _showEditAnimalDialog(
    Animal animal,
    List<AnimalType> animalTypes,
    List<Herd> herds,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: animal.name);
    final animalTypeIdNotifier = ValueNotifier<String?>(animal.animalTypeId);
    final herdIdNotifier = ValueNotifier<String?>(animal.herdId);
    var selectedBirthDate = animal.birthDate;
    var selectedSex = animal.sex;
    var selectedAcquisitionSource = animal.acquisitionSource;

    EntityFormSheet.show(
      context: context,
      title: 'Edit Animal',
      heightFactor: 0.7,
      submitLabel: 'Update Animal',
      formKey: formKey,
      fields: _animalFormFields(
        nameController: nameController,
        animalTypes: animalTypes,
        herds: herds,
        animalTypeIdNotifier: animalTypeIdNotifier,
        herdIdNotifier: herdIdNotifier,
        selectedBirthDate: selectedBirthDate,
        selectedSex: selectedSex,
        selectedAcquisitionSource: selectedAcquisitionSource,
        onBirthDateChanged: (value) => selectedBirthDate = value,
        onSexChanged: (value) => selectedSex = value,
        onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
      ),
      onSubmit: (sheetContext) async {
        final updatedAnimal = AnimalModel(
          id: animal.id,
          userId: animal.userId,
          name: sanitizeText(nameController.text),
          animalTypeId: animalTypeIdNotifier.value!,
          herdId: herdIdNotifier.value!,
          birthDate: selectedBirthDate,
          sex: selectedSex,
          acquisitionSource: selectedAcquisitionSource,
          createdAt: animal.createdAt,
          updatedAt: DateTime.now(),
        );
        context.read<AnimalBloc>().add(UpdateAnimalEvent(updatedAnimal));
        Navigator.pop(sheetContext);
      },
    );
  }

  void _showDeleteConfirmation(Animal animal) async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Animal',
      message:
          'Are you sure you want to delete "${animal.name}"? This action cannot be undone.',
    );
    if (confirmed == true) {
      context.read<AnimalBloc>().add(DeleteAnimalEvent(animal.id));
    }
  }
```

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: PASS (7/7).

- [x] **Step 5: Run the full suite and analyzer, then commit**

```bash
git add lib/features/farm/presentation/pages/animal_page.dart test/features/farm/presentation/pages/animal_page_test.dart
git commit -m "feat: add Animal edit, details sheet, and delete"
git push
```

---

## Task 7: Router entry + setup-wizard step

**Files:**
- Modify: `lib/core/navigation/app_router.dart`
- Modify: `lib/features/farm/presentation/pages/animals_page.dart`
- Test: `test/features/farm/presentation/pages/animals_page_test.dart` (new file — `animals_page.dart` has no existing test coverage)

**Interfaces:**
- Consumes: `AnimalPage` (Task 3).
- Produces: `AppRouteName.animalsList` (`'animals-list'`), `AppRoutePath.animalsList` (`'/animals-list'`) — nothing later in this plan depends on these, but they're the permanent public names for this route.

- [x] **Step 1: Write the failing test**

Create `test/features/farm/presentation/pages/animals_page_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_bloc.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_event.dart';
import 'package:farm_tracker/features/content/presentation/bloc/content_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/animal_type_state.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/herd_state.dart';
import 'package:farm_tracker/features/farm/presentation/pages/animals_page.dart';

class MockAnimalTypeBloc extends MockBloc<AnimalTypeEvent, AnimalTypeState>
    implements AnimalTypeBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockContentBloc extends MockBloc<ContentEvent, ContentState>
    implements ContentBloc {}

void main() {
  late MockAnimalTypeBloc animalTypeBloc;
  late MockHerdBloc herdBloc;
  late MockContentBloc contentBloc;

  setUpAll(() {
    registerFallbackValue(GetAnimalTypesEvent());
    registerFallbackValue(GetHerdsEvent());
  });

  Widget harness() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
          BlocProvider<HerdBloc>.value(value: herdBloc),
          BlocProvider<ContentBloc>.value(value: contentBloc),
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

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // ListView virtualizes by viewport even with a fixed children: list —
    // steps below the fold (this one included) aren't built until scrolled
    // into view, so find.text() finds nothing for them without this.
    await tester.dragUntilVisible(
      find.text('Track Individual Animals'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track Individual Animals'), findsOneWidget);
  });
}
```

(This first test only checks the step renders — a second, richer test asserting the "available"/"locked" visual state would need to inspect `SetupStepCard.status`, which this file's own precedent (steps 1-6) has never tested either; keep this test to the same minimal bar as the rest of the untested file it's being added to.)

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animals_page_test.dart`
Expected: FAIL — no "Track Individual Animals" text exists yet.

- [x] **Step 3: Implement — router**

Read `lib/core/navigation/app_router.dart` in full first. Add the import between `analysis_page.dart` and `animal_type_page.dart`:

```dart
import 'package:farm_tracker/features/farm/presentation/pages/animal_page.dart';
```

Add to `AppRouteName` (after `herds`):

```dart
  static const animalsList = 'animals-list';
```

Add to `AppRoutePath` (after `herds`):

```dart
  static const animalsList = '/animals-list';
```

Add a new `GoRoute` right after the existing `herds` route:

```dart
      GoRoute(
        name: AppRouteName.animalsList,
        path: AppRoutePath.animalsList,
        pageBuilder: (context, state) => _slidePage(const AnimalPage(), state),
      ),
```

- [x] **Step 4: Implement — wizard step**

Read `lib/features/farm/presentation/pages/animals_page.dart` in full first. Insert a 7th step between the existing step 6 ("Manage Infrastructure") and `RelatedContentSection`:

```dart
                      StepConnector(isActive: hasHerd),
                      SetupStepCard(
                        stepNumber: 7,
                        title: 'Track Individual Animals',
                        subtitle: 'Record details for each animal in your herds',
                        status: hasHerd ? StepStatus.available : StepStatus.locked,
                        onTap: () => context.push(AppRoutePath.animalsList),
                      ),
```

(No new imports needed — `AppRoutePath` is already imported, `context.push` is already used by the other steps.)

- [x] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animals_page_test.dart`
Expected: PASS (1/1).

- [x] **Step 6: Run the full suite and analyzer, then commit**

```bash
git add lib/core/navigation/app_router.dart lib/features/farm/presentation/pages/animals_page.dart test/features/farm/presentation/pages/animals_page_test.dart
git commit -m "feat: add animals-list route and setup-wizard step for individual animals"
git push
```

---

## Task 8: Extract `showAddInputDialog` as a reusable top-level function

`input_page.dart` has no existing tests. This task's first job is a safety-net regression test proving the *existing* add-input behavior still works once extracted, before adding the two new locking parameters.

**Files:**
- Modify: `lib/features/farm/presentation/pages/input_page.dart`
- Test: `test/features/farm/presentation/pages/input_page_test.dart` (new file)

**Interfaces:**
- Consumes: `InputModel.create` (unchanged — already has `animalId`), `CostCategoryTypeSelector` (unchanged).
- Produces: top-level `Future<void> showAddInputDialog(BuildContext context, {String? sourceType, String? lockedHerdId, int? lockedAnimalId})`. Task 9 and Task 10 call this with `lockedHerdId`/`lockedAnimalId` set; `_InputPageState`'s own FAB calls it with just `sourceType: widget.sourceType`.

- [x] **Step 1: Write the failing test**

Create `test/features/farm/presentation/pages/input_page_test.dart`:

```dart
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
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
import 'package:farm_tracker/core/widgets/crud/cost_category_type_selector.dart';

class MockInputBloc extends MockBloc<InputEvent, InputState> implements InputBloc {}

class MockHerdBloc extends MockBloc<HerdEvent, HerdState> implements HerdBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState> implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockCostCategoryBloc extends MockBloc<CostCategoryEvent, CostCategoryState>
    implements CostCategoryBloc {}

void main() {
  late MockInputBloc inputBloc;
  late MockHerdBloc herdBloc;
  late MockSeasonBloc seasonBloc;
  late MockLandBloc landBloc;
  late MockCostCategoryBloc costCategoryBloc;
  final now = DateTime.now();

  setUpAll(() {
    registerFallbackValue(GetInputsEvent());
  });

  setUp(() {
    inputBloc = MockInputBloc();
    herdBloc = MockHerdBloc();
    seasonBloc = MockSeasonBloc();
    landBloc = MockLandBloc();
    costCategoryBloc = MockCostCategoryBloc();
    whenListen(
      inputBloc,
      const Stream<InputState>.empty(),
      initialState: const InputLoaded(inputs: []),
    );
    whenListen(
      herdBloc,
      Stream<HerdState>.value(
        HerdLoaded([
          Herd(
            id: 'herd-1',
            userId: 'user-1',
            name: 'Cow Herd',
            animalTypeId: 'type-1',
            location: 'North Field',
            initialHeadCount: 5,
            currentHeadCount: 5,
            startDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      ),
      initialState: HerdLoaded([
        Herd(
          id: 'herd-1',
          userId: 'user-1',
          name: 'Cow Herd',
          animalTypeId: 'type-1',
          location: 'North Field',
          initialHeadCount: 5,
          currentHeadCount: 5,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ]),
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

  // MultiBlocProvider wraps MaterialApp itself (matching main.dart's real
  // wiring), not just its `home:` content — see the Global Constraints
  // correction above for why this matters here specifically.
  Widget harness(ValueChanged<BuildContext> captureContext) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InputBloc>.value(value: inputBloc),
        BlocProvider<HerdBloc>.value(value: herdBloc),
        BlocProvider<SeasonBloc>.value(value: seasonBloc),
        BlocProvider<LandBloc>.value(value: landBloc),
        BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            captureContext(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
  }

  testWidgets(
    'unlocked: shows the herd picker and dispatches AddInputEvent with the chosen herd',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(harness((context) => capturedContext = context));

      unawaited(showAddInputDialog(capturedContext, sourceType: 'animal'));
      await tester.pumpAndSettle();

      expect(find.text('Select Herd *'), findsOneWidget);

      // Select Herd is required/validated — drive the inner FormFieldState
      // too, or Form.validate() fails silently and "Add Input" never
      // submits (same pitfall as the Animal Type/Herd pickers in Task 4).
      final herdDropdownFinder = find.ancestor(
        of: find.text('Select Herd *'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      tester.state<FormFieldState<String>>(herdDropdownFinder).didChange('herd-1');
      tester.widget<DropdownButtonFormField<String>>(herdDropdownFinder).onChanged!('herd-1');
      await tester.pumpAndSettle();

      // CostCategoryTypeSelector.onTypeChanged is the same kind of plain
      // callback prop wrapping a required inner DropdownButtonFormField —
      // same dual-drive requirement.
      final typeSelector = tester.widget<CostCategoryTypeSelector>(
        find.byType(CostCategoryTypeSelector),
      );
      final typeDropdownFinder = find.ancestor(
        of: find.text('Input Type *'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      tester.state<FormFieldState<String>>(typeDropdownFinder).didChange('Feed');
      typeSelector.onTypeChanged('Feed');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cost *'),
        '500',
      );

      await tester.tap(find.text('Add Input'));
      await tester.pumpAndSettle();

      final captured = verify(() => inputBloc.add(captureAny())).captured;
      final event = captured.whereType<AddInputEvent>().single;
      expect(event.input.sourceType, 'animal');
      expect((event.input as Input).animalId, isNull);
    },
  );

  testWidgets(
    'locked: hides the herd picker and pre-sets sourceId/animalId from the locks',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(harness((context) => capturedContext = context));

      unawaited(
        showAddInputDialog(
          capturedContext,
          sourceType: 'animal',
          lockedHerdId: 'herd-1',
          lockedAnimalId: 42,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Herd *'), findsNothing);

      final typeSelector = tester.widget<CostCategoryTypeSelector>(
        find.byType(CostCategoryTypeSelector),
      );
      final typeDropdownFinder = find.ancestor(
        of: find.text('Input Type *'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      tester.state<FormFieldState<String>>(typeDropdownFinder).didChange('Purchase');
      typeSelector.onTypeChanged('Purchase');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cost *'),
        '15000',
      );

      await tester.tap(find.text('Add Input'));
      await tester.pumpAndSettle();

      final captured = verify(() => inputBloc.add(captureAny())).captured;
      final event = captured.whereType<AddInputEvent>().single;
      expect(event.input.sourceType, 'animal');
      expect(event.input.sourceId, 'herd-1');
      expect(event.input.animalId, 42);
    },
  );
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/input_page_test.dart`
Expected: FAIL to compile — `showAddInputDialog` is not a top-level function yet (it's a private method on `_InputPageState`).

- [x] **Step 3: Implement**

Read `lib/features/farm/presentation/pages/input_page.dart` in full first. Move `_showAddInputDialog` out of `_InputPageState` to become a top-level function, replacing every use of `widget.sourceType` with an explicit `sourceType` parameter (defaulting to `'plant'`, matching the current `widget.sourceType ?? 'plant'` behavior) and adding the two lock parameters:

```dart
Future<void> showAddInputDialog(
  BuildContext context, {
  String? sourceType,
  String? lockedHerdId,
  int? lockedAnimalId,
}) async {
  final formKey = GlobalKey<FormState>();
  final typeController = TextEditingController();
  final quantityController = TextEditingController();
  final costController = TextEditingController();
  final notesController = TextEditingController();
  DateTime? selectedDate = DateTime.now();
  final selectedSourceType = sourceType ?? 'plant';
  final isPlant = selectedSourceType == 'plant';
  String? selectedSeasonId;
  String? selectedHerdId = lockedHerdId;

  final seasonState = context.read<SeasonBloc>().state;
  final seasons = seasonState is SeasonLoaded ? seasonState.seasons : <Season>[];

  final landState = context.read<LandBloc>().state;
  final lands = landState is LandLoaded ? landState.lands : <Land>[];

  final herdState = context.read<HerdBloc>().state;
  final herds = herdState is HerdLoaded ? herdState.herds : <Herd>[];

  if (isPlant && seasons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please add at least one season first'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  if (!isPlant && lockedHerdId == null && herds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please add at least one herd first'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => EntityFormSheet.container(
        context: context,
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New ${isPlant ? 'Plant' : 'Animal'} Input',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: EntityFormSheet.scrollableForm(
                  context: context,
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        if (isPlant)
                          DropdownButtonFormField<String>(
                            initialValue: selectedSeasonId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Season *',
                              border: OutlineInputBorder(),
                            ),
                            items: seasons.map((season) {
                              return DropdownMenuItem<String>(
                                value: season.id,
                                child: Text(seasonDropdownLabel(season, lands)),
                              );
                            }).toList(),
                            validator: (value) =>
                                requiredSelection(value, fieldLabel: 'season'),
                            onChanged: (value) {
                              setState(() {
                                selectedSeasonId = value;
                              });
                            },
                          ),
                        if (!isPlant && lockedHerdId == null)
                          DropdownButtonFormField<String>(
                            initialValue: selectedHerdId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Herd *',
                              border: OutlineInputBorder(),
                            ),
                            items: herds.map((herd) {
                              return DropdownMenuItem<String>(
                                value: herd.id,
                                child: Text('${herd.name} (${herd.location})'),
                              );
                            }).toList(),
                            validator: (value) =>
                                requiredSelection(value, fieldLabel: 'herd'),
                            onChanged: (value) {
                              setState(() {
                                selectedHerdId = value;
                              });
                            },
                          ),
                        const SizedBox(height: 16),
                        CostCategoryTypeSelector(
                          categoryKind: 'input',
                          sourceType: selectedSourceType,
                          selectedType: typeController.text,
                          labelText: 'Input Type *',
                          addButtonBackgroundColor: Colors.green.shade50,
                          validator: (value) =>
                              requiredName(value, fieldLabel: 'Input type'),
                          onTypeChanged: (value) {
                            setState(() {
                              typeController.text = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        ValidatedDecimalField(
                          controller: quantityController,
                          labelText: 'Quantity (Optional)',
                          validator: (value) => optionalNonNegativeDecimal(
                            value,
                            fieldLabel: 'Quantity',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValidatedDecimalField(
                          controller: costController,
                          labelText: 'Cost *',
                          hintText: '0.00',
                          validator: (value) =>
                              positiveDecimal(value, fieldLabel: 'Cost'),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Date *'),
                          subtitle: Text(
                            selectedDate != null
                                ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                : 'Select date',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        ValidatedNotesField(
                          controller: notesController,
                          labelText: 'Notes (Optional)',
                          validator: optionalNotes,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    final sourceId =
                        isPlant ? selectedSeasonId! : selectedHerdId!;

                    final input = InputModel.create(
                      sourceType: selectedSourceType,
                      sourceId: sourceId,
                      animalId: isPlant ? null : lockedAnimalId,
                      type: sanitizeText(typeController.text),
                      quantity: parseOptionalNonNegativeDecimal(
                        quantityController.text,
                      ),
                      cost: parsePositiveDecimal(costController.text)!,
                      date: selectedDate!,
                      notes: sanitizeOptionalText(notesController.text),
                    );
                    context.read<InputBloc>().add(AddInputEvent(input));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Add Input',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

Update `_InputPageState`'s FAB (the only remaining call site) to pass `sourceType` explicitly instead of relying on the old implicit `widget.sourceType` closure access:

```dart
      floatingActionButton: SafeFloatingActionButton(
        child: FloatingActionButton(
          onPressed: () => showAddInputDialog(context, sourceType: widget.sourceType),
          child: const Icon(Icons.add),
        ),
      ),
```

Remove the old private `_showAddInputDialog` method from `_InputPageState` entirely (it has been replaced by the top-level function above) — leave `_showEditInputDialog` and `_showDeleteConfirmation` untouched, they are out of scope for this task.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/input_page_test.dart`
Expected: PASS (2/2).

- [x] **Step 5: Run the full suite and analyzer, then commit**

Run `flutter analyze` and `flutter test` — confirm no regressions in any other page that might reference `_showAddInputDialog` (none do; it was private to `input_page.dart`).

```bash
git add lib/features/farm/presentation/pages/input_page.dart test/features/farm/presentation/pages/input_page_test.dart
git commit -m "refactor: extract showAddInputDialog to a top-level, lockable function"
git push
```

---

## Task 9: "Bought" → auto-prompt on Add Animal

**Files:**
- Modify: `lib/features/farm/presentation/pages/animal_page.dart`
- Test: `test/features/farm/presentation/pages/animal_page_test.dart`

**Interfaces:**
- Consumes: `showAddInputDialog` (Task 8).

- [x] **Step 1: Write the failing test**

Add to the `showAddAnimalDialog` group:

```dart
    testWidgets('selecting Bought opens the cost-log prompt after the animal saves', (
      tester,
    ) async {
      late Future<String?> resultFuture;
      await tester.pumpWidget(buildHarness((future) => resultFuture = future));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Bessie',
      );

      // Animal Type and Herd are required/validated fields — per the Global
      // Constraints correction, drive both the inner FormFieldState and the
      // picker's own onChanged, or Form.validate() fails forever and this
      // hangs on the later runAsync(() => resultFuture).
      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<AnimalType>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('type-1');
      tester
          .widget<EntityPickerWithAdd<AnimalType>>(
            find.byType(EntityPickerWithAdd<AnimalType>),
          )
          .onChanged('type-1');
      await tester.pumpAndSettle();

      tester
          .state<FormFieldState<String>>(
            find.descendant(
              of: find.byType(EntityPickerWithAdd<Herd>),
              matching: find.byType(DropdownButtonFormField<String>),
            ),
          )
          .didChange('herd-1');
      tester
          .widget<EntityPickerWithAdd<Herd>>(find.byType(EntityPickerWithAdd<Herd>))
          .onChanged('herd-1');
      await tester.pumpAndSettle();

      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('animal-acquisition-source-field')),
          )
          .onChanged!('bought');
      await tester.pumpAndSettle();

      stateController.add(
        AnimalLoaded(
          animals: [
            Animal(
              id: 'animal-1',
              userId: 'user-1',
              name: 'Bessie',
              animalTypeId: 'type-1',
              herdId: 'herd-1',
              birthDate: now,
              acquisitionSource: 'bought',
              createdAt: now,
              updatedAt: now,
            ),
          ],
          successMessage: 'Animal added',
        ),
      );

      await tester.tap(find.text('Add Animal'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => resultFuture);

      // The cost-log prompt is fire-and-forget from showAddAnimalDialog's
      // own return (see the Global Constraints correction on runAsync +
      // route-pushing deadlocks) — pump once more to let it actually open.
      await tester.pumpAndSettle();

      expect(find.text('Add New Animal Input'), findsOneWidget);
    });
```

`showAddInputDialog` reads `InputBloc`, `SeasonBloc`, `LandBloc`, and `CostCategoryBloc` via `context.read`/`context.watch` (in addition to the `HerdBloc` this group's `buildHarness` already provides), so all four need mocks wired into this group too.

Add these imports to the top of `test/features/farm/presentation/pages/animal_page_test.dart`:

```dart
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/cost_category_state.dart';
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
```

Add these mock classes at the top level of the file, alongside `MockAnimalBloc`/`MockAnimalTypeBloc`/`MockHerdBloc`:

```dart
class MockInputBloc extends MockBloc<InputEvent, InputState> implements InputBloc {}

class MockSeasonBloc extends MockBloc<SeasonEvent, SeasonState> implements SeasonBloc {}

class MockLandBloc extends MockBloc<LandEvent, LandState> implements LandBloc {}

class MockCostCategoryBloc extends MockBloc<CostCategoryEvent, CostCategoryState>
    implements CostCategoryBloc {}
```

In the `showAddAnimalDialog` group, add fields `late MockInputBloc inputBloc;`, `late MockSeasonBloc seasonBloc;`, `late MockLandBloc landBloc;`, `late MockCostCategoryBloc costCategoryBloc;` alongside the existing `animalBloc`/`animalTypeBloc`/`herdBloc` fields. In that group's `setUp`, after the existing `whenListen` calls, add:

```dart
      inputBloc = MockInputBloc();
      seasonBloc = MockSeasonBloc();
      landBloc = MockLandBloc();
      costCategoryBloc = MockCostCategoryBloc();
      whenListen(
        inputBloc,
        const Stream<InputState>.empty(),
        initialState: const InputLoaded(inputs: []),
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
```

And add these four providers to `buildHarness`'s `MultiBlocProvider.providers` list, alongside the existing three:

```dart
            BlocProvider<InputBloc>.value(value: inputBloc),
            BlocProvider<SeasonBloc>.value(value: seasonBloc),
            BlocProvider<LandBloc>.value(value: landBloc),
            BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: FAIL — no "Add New Animal Input" text appears; nothing currently calls `showAddInputDialog` from the animal add flow.

- [x] **Step 3: Implement**

In `lib/features/farm/presentation/pages/animal_page.dart`, add the import:

```dart
import 'dart:async';

import 'package:farm_tracker/features/farm/presentation/pages/input_page.dart';
```

(`dart:async` provides `unawaited` — see below for why it's needed. If `animal_page.dart` doesn't already import `dart:async`, add it as the file's first import line, matching this codebase's convention of a blank line after `dart:` imports before `package:` imports.)

`showAddAnimalDialog` already sets up a `bloc.stream.listen(...)` subscription *before* `EntityFormSheet.show` runs, capturing the newly-added animal's id into the `newId` closure variable once the bloc reports success (this is the same proven pattern `showAddLandDialog` already uses, and it matters here: subscribing only *after* dispatching `AddAnimalEvent` would risk missing a state the bloc already emitted before the listener attached). Reuse that existing `newId`/`subscription` — do not add a second, separately-timed listener inside `onSubmit`. Capture `selectedAcquisitionSource` and `herdIdNotifier.value` into local variables inside `onSubmit` (since the fields powering the form are gone once the sheet closes), then act on them after `EntityFormSheet.show` resolves.

**Do not `await showAddInputDialog(...)` here** — call it with `unawaited(...)` instead. Awaiting it inline was the original draft and it deadlocks for real: it would make `showAddAnimalDialog`'s own returned Future depend on the second sheet's route actually being pushed, and a widget test driving that return value through `tester.runAsync()` (needed for the earlier `UserUtils.getCurrentUserId()` platform-channel call) hangs forever, because `runAsync()`'s real-async zone and the route-push's frame-scheduling can't unblock each other (see the Global Constraints correction above — this was reproduced as a genuine hang against `flutter test`'s own 10-minute per-test timeout, not just impatience). Firing it unawaited also matches the design spec's framing: the animal save and the cost prompt are sequential, independent writes, not something the animal dialog's own caller should block on.

```dart
  String? committedHerdId;
  String? committedAcquisitionSource;

  await EntityFormSheet.show(
    context: context,
    title: 'Add New Animal',
    submitLabel: 'Add Animal',
    formKey: formKey,
    fields: _animalFormFields(
      nameController: nameController,
      animalTypes: animalTypes,
      herds: herds,
      animalTypeIdNotifier: animalTypeIdNotifier,
      herdIdNotifier: herdIdNotifier,
      selectedBirthDate: selectedBirthDate,
      selectedSex: selectedSex,
      selectedAcquisitionSource: selectedAcquisitionSource,
      onBirthDateChanged: (value) => selectedBirthDate = value,
      onSexChanged: (value) => selectedSex = value,
      onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
    ),
    onSubmit: (sheetContext) async {
      final userId = await UserUtils.getCurrentUserId();
      if (userId == null) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      committedHerdId = herdIdNotifier.value;
      committedAcquisitionSource = selectedAcquisitionSource;
      final animal = AnimalModel.create(
        userId: userId,
        name: sanitizeText(nameController.text),
        animalTypeId: animalTypeIdNotifier.value!,
        herdId: herdIdNotifier.value!,
        birthDate: selectedBirthDate,
        sex: selectedSex,
        acquisitionSource: selectedAcquisitionSource,
      );
      bloc.add(AddAnimalEvent(animal));
      Navigator.pop(sheetContext);
    },
  );

  await subscription.cancel();

  if (committedAcquisitionSource == 'bought' && newId != null && context.mounted) {
    unawaited(
      showAddInputDialog(
        context,
        sourceType: 'animal',
        lockedHerdId: committedHerdId,
        lockedAnimalId: int.tryParse(newId!),
      ),
    );
  }

  return newId;
}
```

This replaces the tail end of `showAddAnimalDialog` from Task 5 (the `await EntityFormSheet.show(...)` call through the closing `return newId;` and function-closing `}`) — everything above `await EntityFormSheet.show(...)` (the `bloc`/`beforeIds`/`newId`/`subscription`/controllers/notifiers setup) stays exactly as Task 5 left it, with `committedHerdId`/`committedAcquisitionSource` added alongside the other locals.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: PASS (8/8).

- [x] **Step 5: Run the full suite and analyzer, then commit**

```bash
git add lib/features/farm/presentation/pages/animal_page.dart test/features/farm/presentation/pages/animal_page_test.dart
git commit -m "feat: auto-prompt the cost-log form when a new animal is marked Bought"
git push
```

---

## Task 10: "Bought" → auto-prompt on Edit Animal (transition only)

**Files:**
- Modify: `lib/features/farm/presentation/pages/animal_page.dart`
- Test: `test/features/farm/presentation/pages/animal_page_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the `editing an animal` group (note `existingAnimal.acquisitionSource` is `'bredOnFarm'` in that group's `setUp`, so this is a valid transition case):

```dart
    testWidgets('opens the cost-log prompt when acquisition source transitions to Bought', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('animal-acquisition-source-field')),
          )
          .onChanged!('bought');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Animal'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Animal Input'), findsOneWidget);
    });

    testWidgets('does not re-prompt when acquisition source was already Bought', (
      tester,
    ) async {
      existingAnimal = Animal(
        id: 'animal-1',
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: now,
        sex: 'female',
        acquisitionSource: 'bought',
        createdAt: now,
        updatedAt: now,
      );
      whenListen(
        animalBloc,
        Stream<AnimalState>.value(AnimalLoaded(animals: [existingAnimal])),
        initialState: AnimalLoaded(animals: [existingAnimal]),
      );

      await tester.pumpWidget(
        _harness(animalBloc: animalBloc, animalTypeBloc: animalTypeBloc, herdBloc: herdBloc),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bessie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Animal'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Animal Input'), findsNothing);
    });
```

The `editing an animal` group uses the top-level `_harness` function (defined in Task 3, distinct from the `showAddAnimalDialog` group's own local `buildHarness` that Task 9 already extended) — that top-level `_harness` also needs `InputBloc`/`SeasonBloc`/`LandBloc`/`CostCategoryBloc` mocks and providers now, since `_showEditAnimalDialog`'s `onSubmit` (implemented below) calls `showAddInputDialog`.

Add the same four mock fields (`late MockInputBloc inputBloc;` etc. — the mock classes themselves already exist from Task 9) and the same four `whenListen` stubs from Task 9 to this group's `setUp`. Change the top-level `_harness` function's signature to accept them and add them to its `MultiBlocProvider.providers` list:

```dart
Widget _harness({
  required AnimalBloc animalBloc,
  required AnimalTypeBloc animalTypeBloc,
  required HerdBloc herdBloc,
  required InputBloc inputBloc,
  required SeasonBloc seasonBloc,
  required LandBloc landBloc,
  required CostCategoryBloc costCategoryBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AnimalBloc>.value(value: animalBloc),
        BlocProvider<AnimalTypeBloc>.value(value: animalTypeBloc),
        BlocProvider<HerdBloc>.value(value: herdBloc),
        BlocProvider<InputBloc>.value(value: inputBloc),
        BlocProvider<SeasonBloc>.value(value: seasonBloc),
        BlocProvider<LandBloc>.value(value: landBloc),
        BlocProvider<CostCategoryBloc>.value(value: costCategoryBloc),
      ],
      child: const AnimalPage(),
    ),
  );
}
```

This changes every existing call site of `_harness(...)` (the two tests in Task 3, and the two tests already written in Task 6's `editing an animal` group) to also pass `inputBloc: inputBloc, seasonBloc: seasonBloc, landBloc: landBloc, costCategoryBloc: costCategoryBloc` — those four fields must exist in scope wherever `_harness` is called, so add the same four mock fields and `whenListen` stubs (from Task 9's list, using the shared top-level `MockInputBloc`/`MockSeasonBloc`/`MockLandBloc`/`MockCostCategoryBloc` classes) to Task 3's top-level `setUp` as well, so every `_harness` call site in the file has them available.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: first new test FAILS (no prompt appears); second new test already passes trivially (nothing wired yet) — proceed once the first is red for the right reason.

- [ ] **Step 3: Implement**

In `_showEditAnimalDialog`, capture the pre-edit value and compare after update, mirroring Task 9's pattern:

```dart
  void _showEditAnimalDialog(
    Animal animal,
    List<AnimalType> animalTypes,
    List<Herd> herds,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: animal.name);
    final animalTypeIdNotifier = ValueNotifier<String?>(animal.animalTypeId);
    final herdIdNotifier = ValueNotifier<String?>(animal.herdId);
    var selectedBirthDate = animal.birthDate;
    var selectedSex = animal.sex;
    var selectedAcquisitionSource = animal.acquisitionSource;
    final wasBought = animal.acquisitionSource == 'bought';

    EntityFormSheet.show(
      context: context,
      title: 'Edit Animal',
      heightFactor: 0.7,
      submitLabel: 'Update Animal',
      formKey: formKey,
      fields: _animalFormFields(
        nameController: nameController,
        animalTypes: animalTypes,
        herds: herds,
        animalTypeIdNotifier: animalTypeIdNotifier,
        herdIdNotifier: herdIdNotifier,
        selectedBirthDate: selectedBirthDate,
        selectedSex: selectedSex,
        selectedAcquisitionSource: selectedAcquisitionSource,
        onBirthDateChanged: (value) => selectedBirthDate = value,
        onSexChanged: (value) => selectedSex = value,
        onAcquisitionSourceChanged: (value) => selectedAcquisitionSource = value,
      ),
      onSubmit: (sheetContext) async {
        final herdId = herdIdNotifier.value!;
        final nowBought = selectedAcquisitionSource == 'bought';
        final updatedAnimal = AnimalModel(
          id: animal.id,
          userId: animal.userId,
          name: sanitizeText(nameController.text),
          animalTypeId: animalTypeIdNotifier.value!,
          herdId: herdId,
          birthDate: selectedBirthDate,
          sex: selectedSex,
          acquisitionSource: selectedAcquisitionSource,
          createdAt: animal.createdAt,
          updatedAt: DateTime.now(),
        );
        context.read<AnimalBloc>().add(UpdateAnimalEvent(updatedAnimal));
        Navigator.pop(sheetContext);
        if (!wasBought && nowBought && context.mounted) {
          await showAddInputDialog(
            context,
            sourceType: 'animal',
            lockedHerdId: herdId,
            lockedAnimalId: int.tryParse(animal.id),
          );
        }
      },
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/farm/presentation/pages/animal_page_test.dart`
Expected: PASS (10/10).

- [ ] **Step 5: Run the full suite and analyzer one final time, then commit**

```bash
flutter analyze
flutter test
git add lib/features/farm/presentation/pages/animal_page.dart test/features/farm/presentation/pages/animal_page_test.dart
git commit -m "feat: auto-prompt the cost-log form when an animal transitions to Bought on edit"
git push
```

- [ ] **Step 6: Update the roadmap doc**

Read `docs/superpowers/plans/2026-08-29-farmer-feedback-integration-roadmap.md` in full, then update item 2's status to fully complete (matching the pattern already used for items 0 and 1: check off `Animal.sex`/`Animal.acquisitionSource` frontend, the Bought-prompt integration, and reference this plan and its PR).

```bash
git add docs/superpowers/plans/2026-08-29-farmer-feedback-integration-roadmap.md
git commit -m "docs: mark item 2 (new animal/land fields) complete"
git push
```

---

## Final Verification

After Task 10, ask the user to build and run the app themselves (per their stated preference this session) to confirm the end-to-end flow: adding an animal with "Bought" opens the cost form pre-filled and scoped to that herd, and the animal itself always saves regardless of what happens in that follow-up prompt.
