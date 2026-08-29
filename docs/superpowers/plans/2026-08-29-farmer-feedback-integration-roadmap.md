# Farmer Feedback Integration — Roadmap

> This is a tracking/sequencing document, not a bite-sized TDD implementation
> plan. Each item below gets its own proper implementation plan (via the
> writing-plans flow) written when it's actually picked up — that's when
> backend Go models/migrations get investigated concretely, exact file
> paths get pinned down, and steps get broken into commit-sized pieces.
> Design decisions for every item are already fixed in
> `docs/superpowers/specs/2026-08-29-farmer-feedback-integration-design.md`
> — this doc exists so nothing on the list gets forgotten and the order is
> clear.

## 0. Creatable entity pickers — done, PR open

Branch: `feat/creatable-entity-pickers`. Design: see this session's earlier
brainstorm (not re-written).

- [x] `EntityPickerWithAdd<T>` generic widget, tested (incl. optional
      `prefixIcon`)
- [x] Land add-dialog extracted (`showAddLandDialog`), tested
- [x] Plant add-dialog extracted (`showAddPlantDialog`), tested
- [x] AnimalType add-dialog extracted (`showAddAnimalTypeDialog`), tested
- [x] Herd add-dialog extracted (`showAddHerdDialog`), tested
- [x] Season add-dialog extracted (`showAddSeasonDialog`), tested — its own
      Plant/Land pickers upgraded from a one-time snapshot to reactive
      `BlocBuilder` + `EntityPickerWithAdd`
- [x] Wired into all 7 dropdowns that actually reference an entity list:
  - [x] `season_page.dart` — Plant picker
  - [x] `season_page.dart` — Land picker
  - [x] `herd_page.dart` — AnimalType picker (also upgraded to reactive)
  - [x] `revenue_page.dart` — Season picker
  - [x] `revenue_page.dart` — Herd picker
  - [x] `harvest_page.dart` — Season picker
  - [x] `herd_activity_page.dart` — Herd picker
  - `revenue_page.dart`'s "Select Category" checked and correctly excluded
    — fixed Plant/Animal toggle, not an entity list
- [x] Full test suite green (97/98; the one failure is the stock Flutter
      counter smoke test, pre-existing and unrelated), `flutter analyze`
      clean (0 errors)
- [x] PR into `dev`: https://github.com/NgigiN/jembe_frontend/pull/7

## 1. Default cost category additions — done, PR open

Backend-only. Added `Land Preparation` and `Top Dressing` to
`defaultPlantActivityCategories` in `cost_category_service.go`. No
frontend changes, no backfill (see spec for why).

- [x] Categories added, `go build`/`go vet`/`gofmt`/`go test ./...` all
      clean on branch `feat/plant-cost-categories` (backend repo)
- [x] PR into `dev`: https://github.com/NgigiN/farmers_backend/pull/13

## 2. New animal/land fields — in progress

- [x] Backend: `Land.TenureType`, `Animal.Sex`, `Animal.AcquisitionSource`
      added, validated, tested (`go build`/`go vet`/`gofmt`/`go test ./...`
      all clean). Also fixed a pre-existing bug in `LandService.Update`'s
      `.Select()` allowlist that would have silently dropped the new
      field on update.
  - [x] PR into `dev`: https://github.com/NgigiN/farmers_backend/pull/14
- [x] Frontend: `Land.tenureType` — entity/model round-tripping,
      Add/Edit Land dropdown, details-sheet display, all TDD'd and green.
      Committed on `feat/creatable-entity-pickers`
      (PR https://github.com/NgigiN/jembe_frontend/pull/7).
- [ ] Frontend: `Animal.sex` / `Animal.acquisitionSource` — **blocked**:
      there is no individual-Animal CRUD UI anywhere in the frontend
      (only `Herd`-level aggregate tracking exists; `AnimalModel` is
      referenced only by the repository/data layer, no bloc or
      add/edit page). Adding these as "simple form field additions" per
      the original spec isn't possible until it's decided whether to
      build a new Animal CRUD page/bloc, or take another approach.
      Flagged to the user; not yet resolved.
- [ ] "Bought" → auto-prompt into the existing Input add-flow — depends
      on the above.

## 3. Plant maturity duration

`Plant.maturityDays` (nullable int), preset-picker UI, backend model +
migration. Informational display of expected harvest window on Season —
no reminders.

## 4. Ranges instead of exact numbers

`Herd.initialHeadCount`/`currentHeadCount` and `Land.size` become
min/max pairs. Requires updating every existing read site in cost/summary
analytics to use the midpoint — audit `cost_breakdown.dart`,
`monthly_summary.dart`, and backend equivalents as part of this item, not
after. Range-chip UI replacing the plain number fields in
`herd_page.dart`/`land_page.dart`.

## 5. Animal life-cycle events + production tracking

Largest item. New `AnimalEvent` entity (insemination/birth/deworming/
slaughter) and new `Production` entity (milk per-animal, eggs per-herd,
mirroring `Input`'s `sourceType`/`sourceId` shape). New UI sections on
Animal and Herd detail views. Full backend model/migration/handler work
plus new frontend blocs/pages — likely worth its own decomposition into
two implementation plans (events, then production) when picked up, given
the size.

---

**Next step:** resolve the Animal-UI question blocking the rest of item 2,
then continue to item 3.
