# Farmer Feedback Integration — Design

## Motivation

A batch of raw suggestions from real farmers using Shamba+ was collected and
triaged against the current codebase (`lib/features/farm/`, backend
`internal/models/{animals,plants}`, `internal/services/summaries`). Each
suggestion was checked for whether it's already covered, is a pure UX gap on
existing data, or needs a genuine new field or structural concept. This
document is the design for everything that came out of that triage, minus
the creatable-entity-picker work (already designed and partly implemented —
see **Status: creatable entity pickers**, below, for where that stands).

Full traceability from raw feedback to disposition:

| Farmer feedback (paraphrased) | Disposition |
|---|---|
| Plant variety not in dropdown, want to add it | UX gap — creatable pickers (separate, in-progress work) |
| Animal count / land size feel like a KRA/police audit | **New design: Ranges instead of exact numbers** |
| Land: owned vs. hired | **New design: New animal/land fields** |
| Animal bought vs. bred on-farm vs. gift | **New design: New animal/land fields** |
| Animal sex | **New design: New animal/land fields** |
| Insemination date, birth date | **New design: Animal life-cycle events** |
| Litter/offspring size (e.g. pigs 8-12) | **New design: Animal life-cycle events** |
| Deworming date | **New design: Animal life-cycle events** |
| Slaughter date | **New design: Animal life-cycle events** |
| Milk/egg production | **New design: Production tracking** |
| Plant maturity duration (3mo/6mo/2yr) | **New design: Plant maturity duration** |
| Plant expense categories (land prep, seedlings, weeding, top dressing, harvest) | Mostly already covered — **New design: Default cost category additions** for the 2 real gaps |

## Status: creatable entity pickers (in progress, not re-designed here)

Already has an approved short design and partial implementation on branch
`feat/creatable-entity-pickers`: a generic `EntityPickerWithAdd<T>` widget
(done, tested) plus extracted, id-returning add-dialogs for Land, Plant, and
AnimalType (done, tested). Remaining: extract Herd's and Season's add-dialogs
(more involved — each has its own nested reactive dropdown), then wire the
picker into all 8 dropdown call sites (Season ×2, Herd ×1, Revenue ×3,
Harvest ×1, HerdActivity ×1). No backend changes involved. This continues
under its existing design — it's listed here only so the full roadmap is in
one place.

## Sequencing

After the creatable-pickers work above is finished, the remaining
sub-projects below are tackled in this order (smallest/lowest-risk first):

1. Default cost category additions
2. New animal/land fields
3. Plant maturity duration
4. Ranges instead of exact numbers
5. Animal life-cycle events + production tracking

Each sub-project still gets its own implementation plan (via the
writing-plans flow) when it's actually picked up — this document fixes the
*design* decisions so that step is mechanical, not open-ended. All five
touch the Go backend (`farmTracker/backend`) as well as this Flutter
frontend; none of them are frontend-only.

---

## Sub-project 1: Default cost category additions

**Goal:** add the two plant/activity cost categories farmers explicitly
asked for that don't already exist.

**Current state** (`backend/internal/services/summaries/cost_category_service.go`):
plant/activity defaults are Planting, Harvesting, Weeding, Irrigation,
Pruning, Miscellaneous. "Seedlings" and "harvest cost" are already covered
(Seeds/Nursery, Harvesting). "Land preparing" and "top dressing" (the
activity of applying fertilizer mid-season, distinct from buying it) are
missing.

**Change:** add two entries to `defaultPlantActivityCategories`:
`{Name: "Land Preparation", Type: "plant", Category: "activity", IsDefault: true}`
and `{Name: "Top Dressing", Type: "plant", Category: "activity", IsDefault: true}`.

**No backfill for existing users.** `CostCategoryService.List` only seeds
defaults when a user has zero categories (`count == 0`), so this only
reaches new users automatically. Existing users can already self-serve —
`AddCostCategoryEvent`/`CostCategoryTypeSelector`'s "+" button already lets
any user add a custom category today. A backfill migration is explicitly
out of scope: low value for the risk of a data migration, given the
self-service path already exists.

**No frontend changes.** The Input/Activity pages already read categories
dynamically from the backend.

---

## Sub-project 2: New animal/land fields

**Goal:** three small, independent, additive fields.

**`Land`** (`domain/entities/land.dart` + backend `models/plants` land
model): add `tenureType` — nullable enum, values `owned` / `rented`.
Optional on both create and edit; existing Land rows get `null` (renders as
"—" / not shown, matching how `location`/`soilType` already handle absence).

**`Animal`** (`domain/entities/animal.dart` + backend `models/animals`):
add two nullable fields:
- `sex` — enum, values `male` / `female`. No third "unknown" value; a plain
  `null` already represents "not recorded."
- `acquisitionSource` — enum, values `bought` / `bredOnFarm` / `gift`.

Both optional on create/edit, `null` for existing rows, no backfill.

**Acquisition-source → cost linking:** when the farmer selects "Bought" while
adding or editing an Animal, immediately prompt to log the purchase cost —
open the existing Input add-flow (the same one reachable from Input page
today) pre-filled with `sourceType: 'animal'`, `animalId` set to this
animal, `type` defaulted to a sensible category (e.g. "Purchase" — may need
adding as a new default animal/input cost category, or reuse
"Miscellaneous" if a dedicated one isn't wanted; decide at implementation
time). The animal record itself still saves successfully whether or not the
farmer completes or cancels the cost prompt — the two are sequential but
independent writes, not a single transaction. Selecting "Bred on farm" or
"Gift" does not trigger any prompt.

**UI:** all three fields are simple additions to the existing Land/Animal
add and edit forms (`land_page.dart`, and wherever Animal's add/edit form
lives — `animals_page.dart`) — dropdown/radio selection, no new pages.

---

## Sub-project 3: Plant maturity duration

**Goal:** let a Plant record its typical time-to-harvest, to eventually
show an expected harvest window on a Season using it.

**`Plant`** (`domain/entities/plant.dart` + backend): add `maturityDays` —
nullable integer, number of days from planting to expected harvest. Lives
on `Plant` (the crop-type/variety record), not `Season`, since it's a
property of the crop itself and should default consistently across every
Season that uses that Plant — no per-Season override in this design
(YAGNI; revisit only if a real need for overriding shows up).

**UI:** presented as a friendly picker offering common presets matching the
farmer's own phrasing — "~3 months (90 days)", "~6 months (180 days)",
"~1 year (365 days)", "~2 years (730 days)", plus a "Custom" option for a
raw day count — but stored purely as `maturityDays: int?`. Optional field.

**Usage:** informational only for this design — e.g. Season's detail view
can show "Expected harvest: ~<startDate + maturityDays>" when both the
Season's `startDate` and its Plant's `maturityDays` are known. **No
reminders or notifications** — this app has no push-notification
infrastructure today, and adding one is out of scope here.

---

## Sub-project 4: Ranges instead of exact numbers

**Goal:** replace exact-number entry with range-bucket selection for Herd
headcount and Land size, since farmers report exact figures feel like a
tax/police audit. Litter size (from life-cycle events, sub-project 5)
explicitly stays an exact integer, decided separately — not part of this
sub-project's scope.

**Storage — real min/max, not a derived single number.** This is the one
place existing behavior must change carefully:

- `Herd`: `initialHeadCount`/`currentHeadCount` (currently plain `int`)
  become range pairs — e.g. `initialHeadCountMin`/`initialHeadCountMax`
  and `currentHeadCountMin`/`currentHeadCountMax` (all `int`).
- `Land`: `size` (currently `double?`) becomes `sizeMin`/`sizeMax`
  (`double?`, both null or both set).

**Existing analytics must be updated, not silently broken.** Anything
currently reading `Herd.currentHeadCount`/`Land.size` as a single number
for cost-per-animal / cost-per-hectare calculations (check
`cost_breakdown.dart`, `monthly_summary.dart`, and their backend
equivalents for every read site) switches to using the **midpoint**
`(min + max) / 2` as the working value. This is a required part of this
sub-project's implementation, not a follow-up — a farmer's range choice
must not quietly break existing reports.

**Bucket boundaries** (proposed, confirm/adjust at implementation time
since the farmer's own land example was partially garbled in transcription):
- Animal headcount: `0–2`, `3–5`, `6–10`, `11–20`, `21+`
- Land size (acres): `0–1`, `1–2`, `2–5`, `5–10`, `10+`

The open-ended top bucket (`21+`, `10+`) stores just a `min` with `max:
null`, meaning "at least this many" — analytics should treat a null `max`
as `max = min` (i.e. use `min` as the working value) rather than guessing
an upper bound.

**UI:** range selection via tappable chips/checkboxes (matching the
farmer's own description — "put box to tick") replacing the current plain
number `TextFormField` for these two fields in `herd_page.dart` and
`land_page.dart`. Exactly one bucket selectable per field (single-select
chip group, not multi-select, despite farmers describing it as
checkboxes — the buckets are mutually exclusive ranges).

---

## Sub-project 5: Animal life-cycle events + production tracking

**Goal:** the biggest piece — insemination, birth (with litter size),
deworming, and slaughter as repeating per-animal events; milk and egg
output as ongoing production data.

### Life-cycle events

**New entity `AnimalEvent`** (mirrors the existing `HerdActivity` pattern,
one level down at the individual-animal scale):

```
AnimalEvent
  id: String
  animalId: String
  eventType: enum (insemination, birth, deworming, slaughter)
  date: DateTime
  litterSize: int?        // only meaningful when eventType == birth
  notes: String?
  createdAt: DateTime
```

One generic entity rather than four dedicated ones (`InseminationRecord`,
`BirthRecord`, etc.) — chosen because it's far cheaper to extend with a new
`eventType` later than to add a whole new entity/bloc/data source/page each
time, and the per-type field needs here are minimal (only `litterSize`,
which is simply `null` for non-birth events — this doesn't yet rise to the
"junk drawer" problem that would justify separate entities).

**Litter size** is a plain exact `int?` (per the earlier decision) — no
range treatment, despite pig/dog litters being one of the original
examples; range UI is scoped to sub-project 4 only.

**Slaughter is informational only** — recording a `slaughter` event does
**not** automatically decrement `Herd.currentHeadCount`. That stays a
manual, separate edit to the Herd record. (Auto-adjusting herd counts from
event data is a reasonable future enhancement but adds real complexity —
e.g. deciding whether an animal being slaughtered means the herd's *current*
range should shift down a bucket — that's explicitly deferred.)

**Deworming** carries no special fields beyond the shared shape
(`date`/`notes`) — if a farmer wants to record the cost of a deworming
treatment, that's a separate Input entry (`animalId`-scoped, same pattern
established in sub-project 2's "Bought" flow) they create independently;
this design does not auto-link deworming events to Input the way
"acquisition = bought" does, since deworming cost-logging wasn't
specifically requested.

**UI:** a new "Animal Events" section on the Animal detail view (wherever
`animals_page.dart` currently shows a single animal's details), listing
past events with an "add event" flow that picks `eventType` first, then
shows just the relevant fields (date always; litter size only when
`eventType == birth`).

### Production tracking

**New entity `Production`**, deliberately mirroring the existing `Input`
entity's `sourceType`/`sourceId` shape (already used for exactly this
"could be per-animal or per-herd" ambiguity):

```
Production
  id: String
  sourceType: String       // 'animal' | 'herd'
  sourceId: String         // Animal.id when sourceType == 'animal', Herd.id when 'herd'
  productType: String      // 'milk' | 'eggs' | ... (extensible, not a closed enum)
  quantity: double
  unit: String              // e.g. 'liters', 'eggs' — free text like Harvest.unit
  date: DateTime
  notes: String?
  createdAt: DateTime
  updatedAt: DateTime
```

**Scope split**: milk is recorded per-animal (`sourceType: 'animal'`); eggs
are recorded per-herd/flock (`sourceType: 'herd'`) — matching how farmers
actually track each in practice (individual dairy cows are milked and
recorded separately; eggs are collected per coop, not attributable to one
chicken). `productType` stays an open string rather than a closed enum so a
farmer raising a third product later (wool, honey) doesn't need a schema
change — only new UI copy.

**Not a Revenue record.** Production is a standalone log of *output*,
independent of whether/when it's sold. A farmer who later sells that milk
still creates a separate `Revenue` entry as today — this design does not
auto-convert production into revenue. (A "convert this production entry
into a sale" convenience could be a future enhancement; explicitly out of
scope here.)

**Cadence:** ad-hoc entry only, whenever the farmer chooses to log it — no
scheduled/recurring reminder to log production, consistent with "no
notification infrastructure" from sub-project 3.

**UI:** a new "Production" tab or section — per-animal (accessible from the
Animal detail view, for milk) and per-herd (accessible from the Herd detail
view, for eggs and any other herd-level product) — each a simple add/list
flow matching the existing Harvest page's pattern.

---

## Non-goals (across all five sub-projects)

- No push notifications or reminders anywhere in this design.
- No automatic mutation of `Herd.currentHeadCount` from any event.
- No retroactive backfill of new optional fields for existing records.
- No auto-conversion of Production into Revenue.
- No range treatment for litter size (stays exact).
- No per-Season override of Plant's `maturityDays`.
