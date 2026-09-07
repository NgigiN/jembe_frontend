# RULES — deliberate non-consolidations & invariants (do not "fix")

This file records patterns in `jembe_frontend` / `farm_tracker` that **look** refactorable but are
deliberate. They were reviewed during the pre-release audit (Phase 2 §R2-05) and settled during the
remediation phases. Before "de-duplicating" or "simplifying" any of the below, re-read this.

## 1. The shared CRUD widget kit is THE pattern — reuse it, don't fork it

`lib/core/widgets/crud/` (`entity_card`, `entity_form_sheet`, `entity_details_sheet`,
`entity_empty_view`, `entity_error_view`, `entity_delete_dialog`, `entity_picker_with_add`, the skeleton
list) is duplication *already correctly consolidated* — the best-factored part of the UI. New entity
screens must build on it. The remaining large pages (`analysis_page.dart`, `revenue_page.dart`) should be
extracted *into* this kit over time, **not** grown as parallel bespoke patterns.

## 2. Repository/bloc layering after R2-02 — no pass-through use-case layer

- Repositories are thin: `guard()` (`lib/core/utils/guard.dart`) owns the flag-off
  `try / NetworkException→NetworkFailure / ServerException→ServerFailure / 401→UnauthorizedFailure` dance.
  Don't re-inline that per method.
- The farm feature has **NO use-case layer** — the 66 pass-through use-cases were removed in R2-02 and
  blocs inject the **repository interfaces** directly (`XBloc({required this.repository})`), unwrapping
  params at the call site. **Do not re-introduce `call(p) => repository.m(p)` use-cases** for farm CRUD.
- **Kept on purpose:** `auth`/`profile` use-cases (`GoogleSignInUseCase`, `GetProfile`, `UpdateProfile`,
  `DeleteAccount`) carry real orchestration, and `content_relevance_matcher.dart` /
  `farm_activity_calculator.dart` are real domain logic — these earn their layer.

## 3. No generic `CrudDataSource<T>` — but the parse helpers ARE shared

R2-01 deliberately did **not** introduce a generic `CrudDataSource<T>`. The per-entity offline surface
(offline mixins, conditional request-body fields like `animal_id`, revenue's `total > 0` gate) makes a
generic datasource a *worse* abstraction than the explicit per-entity ones. What IS shared:
`lib/core/utils/json_parsing.dart` (`parseDate`/`parseInt`/`parseDouble`/`dualKey`) — use it in new
datasources instead of re-copying parse code.

## 4. `flutter_secure_storage` + `shared_preferences` overlap is deliberate

Secure storage is primary (auth token, offline DB key); `shared_preferences` is the fallback plus theme
prefs. Keep both. (The *silent* fallback on a secure-storage failure is a separate **security** finding
S4-C2 — a behavior to harden, not a redundancy to collapse.)

## 5. Offline stack ships DARK behind a flag

`OfflineConfig.enabled` (`lib/core/offline/offline_config.dart`) defaults **`false`** and is overridden at
runtime only by the server `/meta offline_enabled` kill-switch. Do **not** flip it to `true` (or hard-code
it) outside the documented release-gate sequence (device encryption-verify + sync-pull-drain + Play
release). The `sync_engine.dart` internals encode careful push/pull ordering and FK reconciliation — treat
them as load-bearing.

## 6. Dependency invariants (Phase 7 R2-06 / D15)

- **Dart SDK floor is `^3.12.0`** (required by go_router 18 / current toolchain). Don't lower it.
- **`go_router` 18.x** — `caseSensitive: false` on all routes and `notifyRootObserver: false` on the
  ShellRoute are intentional behavior-preservation; don't drop them.
- **drift 2.32+ with native-assets `sqlite3mc`** (SQLite3MultipleCiphers) — the `hooks: user_defines:
  sqlite3: source: sqlite3mc` block in `pubspec.yaml` and the `PRAGMA key` in `NativeDatabase(setup:)` are
  the encryption recipe. **Do not** re-pin `drift <2.32` or re-add `sqlcipher_flutter_libs`/
  `sqlite3_flutter_libs` (that was the pre-D15 recipe, now removed).

---
_Origin: pre-release audit `docs/audit/20-redundancy.md` §R2-05, plus decisions from remediation phases
R2-01/R2-02/R2-06. This file lives in the repo so the decision travels with the code — the root `docs/`
audit is local-only, and this repo's `docs/` is gitignored._
