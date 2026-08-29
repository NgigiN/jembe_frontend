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

## 0. Creatable entity pickers — in progress

Branch: `feat/creatable-entity-pickers`. Design: see this session's earlier
brainstorm (not re-written — already approved and partly built).

- [x] `EntityPickerWithAdd<T>` generic widget, tested
- [x] Land add-dialog extracted (`showAddLandDialog`), tested
- [x] Plant add-dialog extracted (`showAddPlantDialog`), tested
- [x] AnimalType add-dialog extracted (`showAddAnimalTypeDialog`), tested
- [ ] Herd add-dialog extracted (`showAddHerdDialog`) — more involved: has
      its own nested `StatefulBuilder` + `BlocBuilder<AnimalTypeBloc>` for a
      live animal-type dropdown, plus `_herdFormFields`,
      `_buildNoAnimalTypesWarning`, `_showSheetError`, `_submitAddHerd` all
      need extracting together
- [ ] Season add-dialog extracted (`showAddSeasonDialog`) — has two of its
      own nested dropdowns (Plant, Land)
- [ ] Wire `EntityPickerWithAdd` into all 8 call sites:
  - [ ] `season_page.dart` — Plant picker
  - [ ] `season_page.dart` — Land picker
  - [ ] `herd_page.dart` — AnimalType picker
  - [ ] `revenue_page.dart` — Category picker
  - [ ] `revenue_page.dart` — Season picker
  - [ ] `revenue_page.dart` — Herd picker
  - [ ] `harvest_page.dart` — Season picker
  - [ ] `herd_activity_page.dart` — Herd picker
- [ ] Push branch, open PR into `dev` once the above lands and behavior is
      demonstrable end to end

## 1. Default cost category additions

Backend-only. Add `Land Preparation` and `Top Dressing` to
`defaultPlantActivityCategories` in `cost_category_service.go`. No
frontend changes, no backfill (see spec for why).

## 2. New animal/land fields

- `Land.tenureType` (owned/rented)
- `Animal.sex` (male/female)
- `Animal.acquisitionSource` (bought/bredOnFarm/gift) + auto-prompt into
  the existing Input add-flow when "bought" is selected
- Backend model + migration for all three, frontend entity/form updates

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

**Next step:** finish item 0 (creatable pickers), then start item 1.
