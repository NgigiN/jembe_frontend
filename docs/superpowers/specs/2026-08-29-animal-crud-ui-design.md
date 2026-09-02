# Individual-Animal CRUD UI — Design

## Background

The farmer-feedback roadmap's item 2 ("New animal/land fields",
`docs/superpowers/plans/2026-08-29-farmer-feedback-integration-roadmap.md`)
calls for adding `Animal.sex` and `Animal.acquisitionSource` to "the
existing Animal add and edit forms." Mid-implementation, no such form
exists: `animals_page.dart` is a setup-wizard hub (`SetupStepCard`s
routing to AnimalTypes/Herds/HerdActivities/Inputs/Activities/
Infrastructure), not an individual-Animal CRUD page. Only Herd-level
aggregate tracking exists in the UI today. The backend `Animal` model,
frontend `AnimalModel`/`AnimalRepositoryImpl`, and all four Animal
usecases (`GetAnimals`/`AddAnimal`/`UpdateAnimal`/`DeleteAnimal`) already
exist in the data layer — only the presentation layer (bloc + page) is
missing.

The user chose to build a new individual-Animal CRUD UI to unblock this,
rather than defer the fields, drop them, or fold them into Herd. This
doc designs that UI and its use of the acquisition-source → cost-form
integration.

Backend `Animal.Sex`/`Animal.AcquisitionSource` are already implemented,
tested, and in an open PR (`farmers_backend#14`) — this doc is
frontend-only.

## Goal

1. A new `AnimalPage` for individual-animal CRUD, following this
   codebase's established entity-page pattern exactly.
2. `sex` and `acquisitionSource` fields on that form.
3. Selecting "Bought" prompts the farmer to log the purchase cost via
   the existing Input add-flow, pre-filled and scoped to that animal.

## Architecture

No further backend changes are needed. Confirmed by reading
`backend/internal/models/plants/input.go` and
`backend/internal/validation/requests.go`: `Input`/`InputRequest`
already carry an optional `AnimalID` field alongside the existing
`SourceType`/`SourceID` (which for `source_type: 'animal'` already means
"scoped to a Herd", per `cost_service.go`'s and `analysis_service.go`'s
existing rollup queries). The frontend `Input` entity/`InputModel`
already round-trip `animalId` end-to-end
(`lib/features/farm/domain/entities/input.dart`,
`lib/features/farm/data/models/input_model.dart`). This was built for
exactly this use case and just needs a caller.

Frontend components, all new:

- **`Animal` entity / `AnimalModel`** gain `sex` (`male`/`female`) and
  `acquisitionSource` (`bought`/`bredOnFarm`/`gift`), both nullable,
  mirroring exactly how `Land.tenureType` was just added (same
  `create`/`fromJson`/`toJson` shape, same validation-free optional
  pattern — validation lives server-side per the existing convention).
- **`AnimalBloc`/`AnimalEvent`/`AnimalState`**, a mechanical mirror of
  `LandBloc`: `GetAnimalsEvent`/`AddAnimalEvent`/`UpdateAnimalEvent`/
  `DeleteAnimalEvent`, each calling the already-existing usecase
  (`GetAnimals(NoParams())`, `AddAnimal(AddAnimalParams(animal: ...))`,
  etc. — these take whole-`Animal`-object params, same shape as Land's
  usecases, not Herd's positional-field style). `AnimalLoaded`/
  `AnimalLoading`/`AnimalError` states mirror `LandState` exactly
  (error keeps the prior list visible, loading shows the list's
  skeleton, success carries a `successMessage` for the snackbar).
  Registered in `main.dart`'s root `MultiBlocProvider` alongside the
  other entity blocs.
- **`AnimalPage`**, mirroring `LandPage`/`HerdPage`: `EntityCard` list,
  add/edit via `EntityFormSheet`, `EntityDetailsSheet`,
  `EntityDeleteDialog`. Add/edit form fields:
  - Name (`ValidatedNameField`)
  - Animal Type — `EntityPickerWithAdd<AnimalType>` (creatable, same as
    `HerdPage`'s existing use)
  - Herd — `EntityPickerWithAdd<Herd>` (creatable), **filtered to herds
    whose `animalTypeId` matches the selected Animal Type** (see Data
    Flow below)
  - Birth Date — `FormField<DateTime?>` + `showDatePicker`, copied from
    `HerdPage`'s existing start-date field pattern
  - Sex — `DropdownButtonFormField<String>` (Male/Female), optional
  - Acquisition Source — `DropdownButtonFormField<String>`
    (Bought/Bred on Farm/Gift), optional
- **Router + navigation**: new route registered the same way as
  `AppRouteName.herds` — `AppRouteName.animalsList = 'animals-list'`,
  `AppRoutePath.animalsList = '/animals-list'` (the plain `animals`
  name/`/animals` path are already taken by the setup-wizard
  dashboard). A
  7th `SetupStepCard` on `animals_page.dart`, "Track Individual
  Animals", gated on `hasHerd` (same gating already used for the
  Inputs/Activities/Herd-Events steps).
- **`showAddInputDialog` extraction**: `_showAddInputDialog` in
  `input_page.dart` (currently a private method on `_InputPageState`,
  reading `SeasonBloc`/`LandBloc`/`HerdBloc`/`InputBloc` via
  `context.read<>()`) is extracted into a top-level function:

  ```dart
  Future<void> showAddInputDialog(
    BuildContext context, {
    String? lockedHerdId,
    int? lockedAnimalId,
  })
  ```

  mirroring the `showAddLandDialog` extraction from item 0 (same
  reasoning: another page needs to trigger this exact flow). All blocs
  it needs are already provided app-wide via `main.dart`'s root
  `MultiBlocProvider`, so this works from any call site, same as
  `showAddLandDialog` already does. When `lockedHerdId`/
  `lockedAnimalId` are passed, the sheet skips the Season/Herd picker
  entirely and pre-sets `sourceType: 'animal'`, `sourceId:
  lockedHerdId`, `animalId: lockedAnimalId`; the farmer only fills in
  type/quantity/cost/date/notes.

## Data Flow

**List/Add/Edit/Delete**: `AnimalPage` dispatches events to
`AnimalBloc`, which calls the existing usecases — pure plumbing, no new
backend calls, identical shape to `LandPage`/`LandBloc`.

**Herd/AnimalType pairing**: `Animal` already carries independent
`animalTypeId` and `herdId` fields (pre-existing, unchanged by this
design), and each `Herd` already has its own fixed `animalTypeId`. To
prevent a farmer creating a mismatched pairing (e.g. animal type "Cow"
assigned to a sheep herd), the Herd picker's item list is filtered to
`herds.where((h) => h.animalTypeId == selectedAnimalTypeId)`. Changing
the Animal Type after a Herd is already selected clears the Herd
selection if it's no longer valid for the new type. This is a pure
form-level UX constraint — no entity or backend validation changes.

**"Bought" → auto-prompt-to-cost-form**:

- **On Add**: `AnimalPage`'s add-submit flow follows the same
  "subscribe to the bloc stream, find the newly-added id" pattern
  `showAddLandDialog` already uses. After `AddAnimalEvent` succeeds and
  the new animal's id is known, if `acquisitionSource == 'bought'`,
  call `showAddInputDialog(context, lockedHerdId: herdId,
  lockedAnimalId: newAnimalId)`.
- **On Edit**: capture the animal's `acquisitionSource` value *before*
  the edit starts. After `UpdateAnimalEvent` succeeds, fire the same
  prompt only if the value was **not** `'bought'` before the edit and
  **is** `'bought'` after — i.e. only on a transition into "bought",
  not on every re-save of an already-`'bought'` animal. This avoids
  re-prompting a farmer who edits an unrelated field (e.g. the name) on
  an animal that was already marked bought.
- The animal record always saves successfully whether or not the
  farmer completes or cancels the cost prompt — these are sequential,
  independent writes, not a transaction, per the original spec.
  Selecting "Bred on farm" or "Gift" never triggers any prompt.

## Error Handling

`AnimalError`/`AnimalLoading`/`AnimalLoaded` follow `LandState`'s
existing shape exactly — no new error-handling design is needed; this
is the sixth entity to use an already-proven pattern. The cost-prompt
step has no error path of its own: if the farmer dismisses or fails to
submit it, the already-saved Animal record is unaffected.

## Testing

TDD throughout, matching this session's established discipline. Two
corrections from investigating the actual codebase (not assumptions):
no bloc anywhere in this codebase has a direct unit test today — bloc
behavior is exercised through page-level widget tests via a
`MockBloc`/`whenListen` harness (see `land_page_test.dart`) — and
`input_page.dart` has zero existing test coverage of any kind. Both are
followed here rather than inventing a new pattern:

- **`AnimalModel`/`Animal` entity**: unit tests for `sex`/
  `acquisitionSource` round-tripping through `create`/`fromJson`/
  `toJson`, mirroring `land_model_test.dart`.
- **`AnimalPage` widget tests** (primary coverage, mirroring
  `land_page_test.dart`'s `MockAnimalBloc`/`whenListen` harness): add,
  edit, list, details, delete flows; the herd-filtered-by-animal-type
  behavior; the two "Bought" auto-prompt cases (add triggers the
  prompt, edit only triggers it on a transition into "bought", not on
  every re-save).
- **`showAddInputDialog` extraction**: since `input_page.dart` has no
  existing tests, this work adds a first test file for it (mirroring
  `land_page_test.dart`'s `showAddLandDialog` test group), covering:
  the existing unlocked behavior still works after the extraction
  (regression safety net for a refactor with no prior coverage), and
  the two new `lockedHerdId`/`lockedAnimalId` parameters correctly
  skip the picker and pre-fill `sourceType`/`sourceId`/`animalId`.

## Out of Scope

- Reconciling individual Animal records with `Herd.initialHeadCount`/
  `currentHeadCount` — these stay fully independent, per the user's
  explicit choice. No validation that they match.
- Any backend changes — `Animal.Sex`/`Animal.AcquisitionSource` and
  `Input.AnimalID` already exist and are already wired end-to-end on
  the frontend `Input` entity.
- A dedicated "Purchase" cost category — the existing Input
  type/category selector is reused as-is; if farmers want a dedicated
  category later, that's a routine `CostCategoryService` addition
  (same shape as item 1's Land Preparation/Top Dressing additions), not
  part of this design.
