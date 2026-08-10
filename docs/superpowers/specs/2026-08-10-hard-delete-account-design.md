# Hard delete account (frontend confirmation + backend endpoint)

Date: 2026-08-10
Status: Approved

## Problem

The frontend already has an in-progress, uncommitted implementation of account deletion: use case, repository, bloc event/state, and a "Danger Zone" entry on the Settings page (`lib/features/farm/presentation/pages/settings_page.dart`) that calls `DELETE /api/v1/profile` via `ProfileRemoteDataSourceImpl.deleteAccount()`. Two things are missing before this is real:

1. **Confirmation strength**: the wired-up dialog reuses `EntityDeleteDialog`, a plain Cancel/Delete two-button dialog shared with routine entity deletes (harvests, land, etc.). Deleting an account is destructive and irreversible across the whole app, so it needs stronger, dedicated friction rather than the generic pattern.
2. **Backend**: `DELETE /api/v1/profile` does not exist yet. The Go backend (`farm-backend`, Gin + GORM + SQLite) has no account-deletion code, and there is no cascade-delete precedent anywhere in the codebase to copy.

Two backend facts shape the design:

- Models declare GORM `constraint:OnDelete:CASCADE`/`RESTRICT` tags (e.g. `internal/models/plants/lands.go`), but `internal/db/db.go` opens SQLite without `PRAGMA foreign_keys=ON`. SQLite does not enforce FKs without that pragma, so **none of these constraints are actually active today** - a plain `DB.Delete(&user)` would not cascade anything.
- Every model embeds `gorm.Model`, which adds a `DeletedAt` soft-delete column. GORM's default `.Delete()` sets that timestamp instead of removing the row. A **true hard delete requires `.Unscoped()`** on every delete call in this feature.

## Approach

### Frontend: typed-confirmation dialog

New widget `TypedDeleteAccountDialog` (`lib/features/profile/presentation/widgets/typed_delete_account_dialog.dart`), account-deletion-specific rather than a change to the shared `EntityDeleteDialog` (which stays as-is for routine entity deletes elsewhere). Behavior:

- `AlertDialog` with the same "this permanently deletes your account and all farm data ... cannot be undone" message already drafted in the current diff.
- A `TextField` below the message. The "Delete" action button is disabled (`onPressed: null`) until the field's contents exactly equal the literal string `DELETE` (case-sensitive, no trim-and-fuzzy-match).
- Cancel button pops `false`; enabled Delete button pops `true` - same `Future<bool?>` contract as `EntityDeleteDialog.show`, so it's a drop-in replacement.

`_onDeleteAccount()` in `settings_page.dart` swaps its `EntityDeleteDialog.show(...)` call for `TypedDeleteAccountDialog.show(...)`. Everything downstream (`DeleteAccountEvent` → `ProfileBloc` → `DeleteAccount` use case → `ProfileRepositoryImpl` → `ProfileRemoteDataSourceImpl.deleteAccount()` → `DELETE /api/v1/profile` → `AccountDeleted` state → logout) is already implemented in the current diff and needs no changes.

No backend password re-check: the existing JWT auth middleware already proves this is an authenticated session, and the typed-confirmation step is the agreed source of friction. Keeps the endpoint body-less, matching `GetProfile`'s simplicity.

### Backend: `DELETE /api/v1/profile`

**Route** (`internal/routes/routes.go`, inside the existing `profile` group):
```go
profile.DELETE("", userHandler.DeleteAccount)
```

**Handler** (`internal/handlers/users/user_handler.go`), mirrors `GetProfile`/`ChangePassword`: read `user_id` from context, call the service, respond `200 {"message": "Account deleted successfully"}` on success, `validation.RespondError(c, err)` on failure (matches existing error-mapping convention - no new response shape).

**Service** (`internal/services/users/user_service.go`), new `DeleteAccount(userID uint) error`, wrapping all deletes in one `s.DB.Transaction(func(tx *gorm.DB) error { ... })` so a failure partway rolls back everything instead of leaving orphaned rows. Every call uses `.Unscoped().Where("user_id = ?", userID).Delete(&Model{})` for true hard delete, executed in this order (children before parents, even though FK enforcement is currently inactive - this is the intended semantic order and protects against future enablement of the pragma):

1. `plants.Harvest` (references Season)
2. `plants.Activity`
3. `plants.Input`
4. `plants.Season` (references Plant, Land)
5. `plants.Plant`
6. `plants.Land`
7. `animals.AnimalActivity`
8. `animals.AnimalInput`
9. `animals.HerdActivity` - no `user_id` column, so delete via subquery: `tx.Unscoped().Where("herd_id IN (?)", tx.Model(&animals.Herd{}).Select("id").Where("user_id = ?", userID)).Delete(&animals.HerdActivity{})`
10. `animals.Animal`
11. `animals.Herd`
12. `animals.Infrastructure`
13. `animals.AnimalType`
14. `summaries.Revenue`
15. `summaries.CostCategory`
16. `users.User` itself - `tx.Unscoped().Delete(&models.User{}, userID)`

No sessions/refresh-token table exists (JWTs are stateless, verified via HMAC secret only), so there is nothing else server-side to invalidate. Frontend clears local session via the existing `LogoutEvent` dispatch after `AccountDeleted`.

**Testing**: extend `internal/services/users/user_service_test.go` (existing in-memory-sqlite-per-test convention) with a test that seeds representative rows across the plant, animal, and summary modules for two different users, calls `DeleteAccount` for one of them, and asserts (with `Unscoped()` queries, since soft-deleted rows would otherwise still count) that every row belonging to the deleted user - including the user row itself - is gone, while the other user's rows are untouched.

## Commit scope (both repos)

Frontend commit includes only: the already-diffed profile/settings delete-account files (`profile_remote_data_source.dart`, `profile_repository_impl.dart`, `profile_repository.dart`, `delete_account.dart`, `profile_bloc.dart`, `profile_event.dart`, `profile_state.dart`, `injection_container.dart`, `settings_page.dart`) plus the new `typed_delete_account_dialog.dart`. It excludes the unrelated changes currently sitting in the working tree: `.github/workflows/release.yml` (Flutter version bump), `onboarding_page.dart` (rebrand copy), `pubspec.lock` (dependency bumps), and the untracked `docs/play-store/` and `support/` directories.

Backend commit is the new route/handler/service/test files - nothing pre-existing to exclude, since the backend working tree is currently clean.
