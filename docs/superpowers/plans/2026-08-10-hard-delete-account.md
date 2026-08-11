# Hard Delete Account Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a real `DELETE /api/v1/profile` endpoint on the Go backend that permanently hard-deletes a user and all their farm data, and swap the frontend's account-deletion confirmation from a plain Cancel/Delete dialog to one that requires typing "DELETE" first.

**Architecture:** Backend: one new `UserService.DeleteAccount(userID)` method wrapping a `gorm.DB.Transaction` that hard-deletes (`.Unscoped()`) rows across every farm-data table by `user_id` in dependency order, then the user row itself, exposed via a new handler + route mirroring the existing `GetProfile`/`ChangePassword` pattern. Frontend: a new `TypedDeleteAccountDialog` widget (new file, not a change to the shared `EntityDeleteDialog`) wired into the already-implemented delete-account bloc/use-case/repository pipeline in `settings_page.dart`.

**Tech Stack:** Backend: Go, Gin, GORM, SQLite (`gorm.io/driver/sqlite`), in-memory-sqlite test convention. Frontend: Flutter, flutter_bloc, dartz (`Either`), flutter_test + bloc_test + mocktail.

**Repos:**
- Backend: `/home/ngigi/Documents/projects/farmTracker/backend` (module `farm-backend`)
- Frontend: `/home/ngigi/Documents/projects/farmTracker/frontend` (package `farm_tracker`)

## Global Constraints

- **True hard delete, not soft delete:** every model embeds `gorm.Model`, which adds `DeletedAt`. GORM's plain `.Delete()` sets that timestamp instead of removing the row. Every delete call in this feature must use `.Unscoped()`.
- **No FK cascade reliance:** SQLite's `PRAGMA foreign_keys` is never enabled in this codebase (`internal/db/db.go`), so declared `constraint:OnDelete:CASCADE/RESTRICT` GORM tags are not enforced. Deletion order must be handled explicitly in application code (children before parents).
- **Endpoint contract:** `DELETE /api/v1/profile`, no request body, auth via the existing JWT middleware's `user_id` context key (same pattern as `GetProfile`/`UpdateProfile`/`ChangePassword`), success response `200 {"message": "Account deleted successfully"}`. No backend password re-check (per approved spec).
- **Frontend confirmation gate:** the Delete action stays disabled until the user has typed the literal, case-sensitive string `DELETE` into a text field.
- **Commit scope:** each task commits only the files it lists. The final frontend task must NOT stage `.github/workflows/release.yml`, `lib/features/auth/presentation/pages/onboarding_page.dart`, `pubspec.lock`, `docs/play-store/`, or `support/` — these are pre-existing unrelated changes in the working tree.

---

### Task 1: Backend — `UserService.DeleteAccount` cascading hard delete

**Repo:** backend

**Files:**
- Modify: `internal/services/users/user_service.go`
- Test: `internal/services/users/user_service_test.go`

**Interfaces:**
- Produces: `func (s *UserService) DeleteAccount(userID uint) error` — consumed by Task 2's handler.

- [ ] **Step 1: Write the failing test**

Replace the import block at the top of `internal/services/users/user_service_test.go`:

```go
import (
	"errors"
	"testing"
	"time"

	animalModels "farm-backend/internal/models/animals"
	plantModels "farm-backend/internal/models/plants"
	summaryModels "farm-backend/internal/models/summaries"
	models "farm-backend/internal/models/users"
	"farm-backend/internal/validation"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)
```

Append the following to the end of the file:

```go
func setupUserTestDBWithFarmData(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to open test db: %v", err)
	}
	if err := db.AutoMigrate(
		&models.User{},
		&plantModels.Plant{},
		&plantModels.Land{},
		&plantModels.Season{},
		&plantModels.Harvest{},
		&plantModels.Activity{},
		&plantModels.Input{},
		&animalModels.AnimalType{},
		&animalModels.Herd{},
		&animalModels.Animal{},
		&animalModels.AnimalActivity{},
		&animalModels.AnimalInput{},
		&animalModels.HerdActivity{},
		&animalModels.Infrastructure{},
		&summaryModels.Revenue{},
		&summaryModels.CostCategory{},
	); err != nil {
		t.Fatalf("failed to migrate: %v", err)
	}
	return db
}

// seedFarmDataForUser creates one row in every farm-data table for userID and
// returns the seeded herd's ID, since HerdActivity has no user_id column and
// must be checked by herd_id directly rather than through a subquery that
// would silently pass once the owning herd itself is gone.
func seedFarmDataForUser(t *testing.T, db *gorm.DB, userID uint) (herdID uint) {
	t.Helper()

	plant := plantModels.Plant{UserID: userID, Name: "Maize"}
	if err := db.Create(&plant).Error; err != nil {
		t.Fatalf("seed plant: %v", err)
	}
	land := plantModels.Land{UserID: userID, Name: "North Field"}
	if err := db.Create(&land).Error; err != nil {
		t.Fatalf("seed land: %v", err)
	}
	season := plantModels.Season{
		UserID:    userID,
		Name:      "2026 Long Rains",
		PlantID:   plant.ID,
		LandID:    land.ID,
		StartDate: time.Now(),
	}
	if err := db.Create(&season).Error; err != nil {
		t.Fatalf("seed season: %v", err)
	}
	harvest := plantModels.Harvest{
		UserID:   userID,
		SeasonID: season.ID,
		Quantity: 10,
		Unit:     "kg",
		Date:     time.Now(),
	}
	if err := db.Create(&harvest).Error; err != nil {
		t.Fatalf("seed harvest: %v", err)
	}
	activity := plantModels.Activity{
		UserID:     userID,
		SourceType: "plant",
		SourceID:   season.ID,
		Type:       "weeding",
		Details:    "weeded rows",
	}
	if err := db.Create(&activity).Error; err != nil {
		t.Fatalf("seed activity: %v", err)
	}
	input := plantModels.Input{
		UserID:     userID,
		SourceType: "plant",
		SourceID:   season.ID,
		Type:       "fertilizer",
		Quantity:   5,
		Cost:       500,
		Date:       time.Now(),
	}
	if err := db.Create(&input).Error; err != nil {
		t.Fatalf("seed input: %v", err)
	}

	animalType := animalModels.AnimalType{UserID: userID, Name: "Cows"}
	if err := db.Create(&animalType).Error; err != nil {
		t.Fatalf("seed animal type: %v", err)
	}
	herd := animalModels.Herd{
		UserID:       userID,
		Name:         "Herd A",
		AnimalTypeID: animalType.ID,
		Location:     "Paddock 1",
		StartDate:    time.Now(),
	}
	if err := db.Create(&herd).Error; err != nil {
		t.Fatalf("seed herd: %v", err)
	}
	animal := animalModels.Animal{
		UserID:       userID,
		AnimalTypeID: animalType.ID,
		HerdID:       herd.ID,
		Name:         "Bessie",
		BirthDate:    time.Now(),
	}
	if err := db.Create(&animal).Error; err != nil {
		t.Fatalf("seed animal: %v", err)
	}
	herdActivity := animalModels.HerdActivity{
		HerdID:       herd.ID,
		ActivityType: "birth",
		Count:        1,
		Date:         time.Now(),
	}
	if err := db.Create(&herdActivity).Error; err != nil {
		t.Fatalf("seed herd activity: %v", err)
	}
	animalActivity := animalModels.AnimalActivity{
		UserID:   userID,
		HerdID:   herd.ID,
		AnimalID: animal.ID,
		Type:     "vaccination",
		Details:  "annual shot",
		Date:     time.Now(),
	}
	if err := db.Create(&animalActivity).Error; err != nil {
		t.Fatalf("seed animal activity: %v", err)
	}
	animalInput := animalModels.AnimalInput{
		UserID:   userID,
		HerdID:   herd.ID,
		AnimalID: animal.ID,
		Type:     "feed",
		Quantity: 2,
		Cost:     100,
		Date:     time.Now(),
	}
	if err := db.Create(&animalInput).Error; err != nil {
		t.Fatalf("seed animal input: %v", err)
	}
	infrastructure := animalModels.Infrastructure{
		UserID:   userID,
		Type:     "House",
		Name:     "Coop 1",
		Location: "Paddock 1",
		Cost:     1000,
		Date:     time.Now(),
	}
	if err := db.Create(&infrastructure).Error; err != nil {
		t.Fatalf("seed infrastructure: %v", err)
	}

	revenue := summaryModels.Revenue{
		UserID:    userID,
		Source:    "harvest",
		Type:      "plant",
		Quantity:  10,
		UnitPrice: 50,
		Total:     500,
		Date:      time.Now(),
	}
	if err := db.Create(&revenue).Error; err != nil {
		t.Fatalf("seed revenue: %v", err)
	}
	costCategory := summaryModels.CostCategory{
		UserID:   userID,
		Name:     "Fertilizer",
		Type:     "plant",
		Category: "input",
	}
	if err := db.Create(&costCategory).Error; err != nil {
		t.Fatalf("seed cost category: %v", err)
	}

	return herd.ID
}

func assertFarmDataRowCounts(t *testing.T, db *gorm.DB, userID uint, expected int64) {
	t.Helper()
	tables := []any{
		&plantModels.Plant{}, &plantModels.Land{}, &plantModels.Season{},
		&plantModels.Harvest{}, &plantModels.Activity{}, &plantModels.Input{},
		&animalModels.AnimalType{}, &animalModels.Herd{}, &animalModels.Animal{},
		&animalModels.AnimalActivity{}, &animalModels.AnimalInput{},
		&animalModels.Infrastructure{}, &summaryModels.Revenue{}, &summaryModels.CostCategory{},
	}
	for _, model := range tables {
		var count int64
		if err := db.Unscoped().Model(model).Where("user_id = ?", userID).Count(&count).Error; err != nil {
			t.Fatalf("count rows for %T: %v", model, err)
		}
		if count != expected {
			t.Fatalf("expected %d rows of %T for user %d, found %d", expected, model, userID, count)
		}
	}
}

func TestUserService_DeleteAccountHardDeletesAllFarmData(t *testing.T) {
	db := setupUserTestDBWithFarmData(t)

	owner := models.User{Email: "owner@example.com", FirstName: "Owner", LastName: "One"}
	if err := db.Create(&owner).Error; err != nil {
		t.Fatalf("create owner: %v", err)
	}
	other := models.User{Email: "other@example.com", FirstName: "Other", LastName: "Two"}
	if err := db.Create(&other).Error; err != nil {
		t.Fatalf("create other user: %v", err)
	}

	ownerHerdID := seedFarmDataForUser(t, db, owner.ID)
	otherHerdID := seedFarmDataForUser(t, db, other.ID)

	service := NewUserService(db)
	if err := service.DeleteAccount(owner.ID); err != nil {
		t.Fatalf("delete account: %v", err)
	}

	assertFarmDataRowCounts(t, db, owner.ID, 0)
	assertFarmDataRowCounts(t, db, other.ID, 1)

	var ownerHerdActivityCount int64
	if err := db.Unscoped().Model(&animalModels.HerdActivity{}).
		Where("herd_id = ?", ownerHerdID).Count(&ownerHerdActivityCount).Error; err != nil {
		t.Fatalf("count owner herd activities: %v", err)
	}
	if ownerHerdActivityCount != 0 {
		t.Fatalf("expected owner's herd activity rows to be gone, found %d", ownerHerdActivityCount)
	}

	var otherHerdActivityCount int64
	if err := db.Unscoped().Model(&animalModels.HerdActivity{}).
		Where("herd_id = ?", otherHerdID).Count(&otherHerdActivityCount).Error; err != nil {
		t.Fatalf("count other user's herd activities: %v", err)
	}
	if otherHerdActivityCount != 1 {
		t.Fatalf("expected other user's herd activity row to remain, found %d", otherHerdActivityCount)
	}

	var deletedUser models.User
	err := db.Unscoped().First(&deletedUser, owner.ID).Error
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		t.Fatalf("expected owner user row to be hard-deleted, got err=%v", err)
	}

	var remainingUser models.User
	if err := db.Unscoped().First(&remainingUser, other.ID).Error; err != nil {
		t.Fatalf("expected other user to remain, got err=%v", err)
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/ngigi/Documents/projects/farmTracker/backend && go test ./internal/services/users/... -run TestUserService_DeleteAccountHardDeletesAllFarmData -v`
Expected: FAIL to compile — `service.DeleteAccount undefined (type *UserService has no field or method DeleteAccount)`

- [ ] **Step 3: Write the minimal implementation**

Replace the import block at the top of `internal/services/users/user_service.go`:

```go
import (
	"errors"
	"log/slog"

	animalModels "farm-backend/internal/models/animals"
	plantModels "farm-backend/internal/models/plants"
	summaryModels "farm-backend/internal/models/summaries"
	models "farm-backend/internal/models/users"
	"farm-backend/internal/validation"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)
```

Append this method to the end of `internal/services/users/user_service.go`:

```go
// DeleteAccount permanently and irreversibly deletes userID and every row of
// farm data they own. PRAGMA foreign_keys is never enabled for this app's
// SQLite connection (see internal/db/db.go), so the declared GORM
// OnDelete:CASCADE/RESTRICT tags are not enforced - each table is deleted
// explicitly here, children before parents, inside one transaction so a
// failure partway through leaves nothing orphaned. Unscoped() is required on
// every call because gorm.Model's soft-delete would otherwise just set
// deleted_at instead of removing the row.
func (s *UserService) DeleteAccount(userID uint) error {
	return s.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&plantModels.Harvest{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&plantModels.Activity{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&plantModels.Input{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&plantModels.Season{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&plantModels.Plant{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&plantModels.Land{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&animalModels.AnimalActivity{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&animalModels.AnimalInput{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().
			Where("herd_id IN (?)", tx.Model(&animalModels.Herd{}).Select("id").Where("user_id = ?", userID)).
			Delete(&animalModels.HerdActivity{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&animalModels.Animal{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&animalModels.Herd{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&animalModels.Infrastructure{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&animalModels.AnimalType{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&summaryModels.Revenue{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Where("user_id = ?", userID).Delete(&summaryModels.CostCategory{}).Error; err != nil {
			return err
		}
		if err := tx.Unscoped().Delete(&models.User{}, userID).Error; err != nil {
			return err
		}
		return nil
	})
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /home/ngigi/Documents/projects/farmTracker/backend && go test ./internal/services/users/... -v`
Expected: PASS — all tests in the package, including `TestUserService_DeleteAccountHardDeletesAllFarmData` and the three pre-existing `TestUserService_*` tests.

- [ ] **Step 5: Commit**

```bash
cd /home/ngigi/Documents/projects/farmTracker/backend
git add internal/services/users/user_service.go internal/services/users/user_service_test.go
git commit -m "feat: add cascading hard delete for user accounts"
```

---

### Task 2: Backend — wire `DELETE /api/v1/profile` handler and route

**Repo:** backend

**Files:**
- Modify: `internal/handlers/users/user_handler.go`
- Modify: `internal/routes/routes.go`

**Interfaces:**
- Consumes: `UserService.DeleteAccount(userID uint) error` (Task 1).
- Produces: `DELETE /api/v1/profile` HTTP route, response `200 {"message": "Account deleted successfully"}` on success.

- [ ] **Step 1: Add the handler method**

Append to the end of `internal/handlers/users/user_handler.go`:

```go

// DeleteAccount permanently deletes the currently logged-in user's account and all their farm data
func (h *UserHandler) DeleteAccount(c *gin.Context) {
	val, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := val.(uint)

	if err := h.UserService.DeleteAccount(userID); err != nil {
		validation.RespondError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account deleted successfully"})
}
```

- [ ] **Step 2: Register the route**

In `internal/routes/routes.go`, change:

```go
		profile := protected.Group("/profile")
		{
			profile.GET("", userHandler.GetProfile)
			profile.PUT("", userHandler.UpdateProfile)
			profile.PUT("/password", userHandler.ChangePassword)
		}
```

to:

```go
		profile := protected.Group("/profile")
		{
			profile.GET("", userHandler.GetProfile)
			profile.PUT("", userHandler.UpdateProfile)
			profile.PUT("/password", userHandler.ChangePassword)
			profile.DELETE("", userHandler.DeleteAccount)
		}
```

- [ ] **Step 3: Build and run the full backend test suite**

Run: `cd /home/ngigi/Documents/projects/farmTracker/backend && go build ./...`
Expected: exits 0, no output.

Run: `cd /home/ngigi/Documents/projects/farmTracker/backend && make test`
Expected: all packages PASS, including `internal/services/users` from Task 1.

- [ ] **Step 4: Commit**

```bash
cd /home/ngigi/Documents/projects/farmTracker/backend
git add internal/handlers/users/user_handler.go internal/routes/routes.go
git commit -m "feat: expose DELETE /api/v1/profile endpoint"
```

---

### Task 3: Frontend — `TypedDeleteAccountDialog` widget

**Repo:** frontend

**Files:**
- Create: `lib/features/profile/presentation/widgets/typed_delete_account_dialog.dart`
- Test: `test/features/profile/presentation/widgets/typed_delete_account_dialog_test.dart`

**Interfaces:**
- Produces: `TypedDeleteAccountDialog.show({required BuildContext context, required String title, required String message}) → Future<bool?>` — same `Future<bool?>` contract as the existing `EntityDeleteDialog.show`, consumed by Task 4.

- [ ] **Step 1: Write the failing test**

Create `test/features/profile/presentation/widgets/typed_delete_account_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_tracker/features/profile/presentation/widgets/typed_delete_account_dialog.dart';

void main() {
  Future<void> pumpDialogHost(
    WidgetTester tester, {
    required void Function(Future<bool?> result) onOpened,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                onOpened(
                  TypedDeleteAccountDialog.show(
                    context: context,
                    title: 'Delete Account',
                    message:
                        'This permanently deletes your account and all '
                        'farm data. This cannot be undone.',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Delete button stays disabled until DELETE is typed exactly', (
    tester,
  ) async {
    Future<bool?>? resultFuture;
    await pumpDialogHost(tester, onOpened: (result) => resultFuture = result);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final deleteButtonFinder = find.widgetWithText(TextButton, 'Delete');
    expect(tester.widget<TextButton>(deleteButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<TextButton>(deleteButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(
      tester.widget<TextButton>(deleteButtonFinder).onPressed,
      isNotNull,
    );

    await tester.tap(deleteButtonFinder);
    await tester.pumpAndSettle();

    expect(await resultFuture, isTrue);
  });

  testWidgets('Cancel pops false without requiring typed confirmation', (
    tester,
  ) async {
    Future<bool?>? resultFuture;
    await pumpDialogHost(tester, onOpened: (result) => resultFuture = result);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/ngigi/Documents/projects/farmTracker/frontend && flutter test test/features/profile/presentation/widgets/typed_delete_account_dialog_test.dart`
Expected: FAIL to compile — `Target of URI doesn't exist: 'package:farm_tracker/features/profile/presentation/widgets/typed_delete_account_dialog.dart'`

- [ ] **Step 3: Write the minimal implementation**

Create `lib/features/profile/presentation/widgets/typed_delete_account_dialog.dart`:

```dart
import 'package:flutter/material.dart';

class TypedDeleteAccountDialog {
  static const confirmationPhrase = 'DELETE';

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          _TypedDeleteAccountDialogContent(title: title, message: message),
    );
  }
}

class _TypedDeleteAccountDialogContent extends StatefulWidget {
  const _TypedDeleteAccountDialogContent({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<_TypedDeleteAccountDialogContent> createState() =>
      _TypedDeleteAccountDialogContentState();
}

class _TypedDeleteAccountDialogContentState
    extends State<_TypedDeleteAccountDialogContent> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final isConfirmed = value == TypedDeleteAccountDialog.confirmationPhrase;
    if (isConfirmed != _isConfirmed) {
      setState(() => _isConfirmed = isConfirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          Text(
            'Type ${TypedDeleteAccountDialog.confirmationPhrase} to confirm.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isConfirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /home/ngigi/Documents/projects/farmTracker/frontend && flutter test test/features/profile/presentation/widgets/typed_delete_account_dialog_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd /home/ngigi/Documents/projects/farmTracker/frontend
git add lib/features/profile/presentation/widgets/typed_delete_account_dialog.dart test/features/profile/presentation/widgets/typed_delete_account_dialog_test.dart
git commit -m "feat: add typed-confirmation dialog for destructive account deletion"
```

---

### Task 4: Frontend — wire dialog into Settings and finalize the feature commit

**Repo:** frontend

**Files:**
- Modify: `lib/features/farm/presentation/pages/settings_page.dart`
- Modify: `test/features/farm/presentation/pages/settings_page_test.dart`
- Also part of this commit (pre-existing uncommitted changes already in the working tree that implement the rest of the delete-account pipeline — not created by this task, but this is the first point they're committed): `lib/features/profile/data/datasources/profile_remote_data_source.dart`, `lib/features/profile/data/repositories/profile_repository_impl.dart`, `lib/features/profile/domain/repositories/profile_repository.dart`, `lib/features/profile/domain/usecases/delete_account.dart`, `lib/features/profile/presentation/bloc/profile_bloc.dart`, `lib/features/profile/presentation/bloc/profile_event.dart`, `lib/features/profile/presentation/bloc/profile_state.dart`, `lib/injection_container.dart`.

**Interfaces:**
- Consumes: `TypedDeleteAccountDialog.show(...)` (Task 3), and the already-implemented `DeleteAccountEvent`, `ProfileBloc`, `AccountDeleted` state (pre-existing in the working tree).

- [ ] **Step 1: Swap the dialog in `settings_page.dart`**

Change the import:

```dart
import 'package:farm_tracker/core/widgets/crud/entity_delete_dialog.dart';
```

to:

```dart
import 'package:farm_tracker/features/profile/presentation/widgets/typed_delete_account_dialog.dart';
```

Change `_onDeleteAccount`:

```dart
  Future<void> _onDeleteAccount() async {
    final confirmed = await EntityDeleteDialog.show(
      context: context,
      title: 'Delete Account',
      message:
          'This permanently deletes your account and all farm data '
          '(harvests, land, animals, revenue, costs). This cannot be undone.',
    );
    if (confirmed ?? false) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(DeleteAccountEvent());
    }
  }
```

to:

```dart
  Future<void> _onDeleteAccount() async {
    final confirmed = await TypedDeleteAccountDialog.show(
      context: context,
      title: 'Delete Account',
      message:
          'This permanently deletes your account and all farm data '
          '(harvests, land, animals, revenue, costs). This cannot be undone.',
    );
    if (confirmed ?? false) {
      if (!mounted) return;
      context.read<ProfileBloc>().add(DeleteAccountEvent());
    }
  }
```

- [ ] **Step 2: Add a settings-page test for the new confirmation gate**

Append this `testWidgets` block inside `main()` in `test/features/farm/presentation/pages/settings_page_test.dart` (after the existing test, before the closing `}`):

```dart

  testWidgets(
    'Delete Account requires typing DELETE before dispatching DeleteAccountEvent',
    (tester) async {
      final profileBloc = MockProfileBloc();
      final themeBloc = MockThemeBloc();
      final authBloc = MockAuthBloc();

      const user = User(
        id: '1',
        email: 'a@example.com',
        firstName: 'A',
        lastName: 'B',
        farmName: 'Green Acres',
        location: 'Nakuru',
        pictureUrl: '',
        fiscalYearStartMonth: 1,
      );

      whenListen(
        profileBloc,
        Stream<ProfileState>.value(const ProfileLoaded(user: user)),
        initialState: const ProfileLoaded(user: user),
      );
      whenListen(
        themeBloc,
        Stream<ThemeState>.value(const ThemeState(themeMode: ThemeMode.light)),
        initialState: const ThemeState(themeMode: ThemeMode.light),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<ThemeBloc>.value(value: themeBloc),
              BlocProvider<AuthBloc>.value(value: authBloc),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Delete Account'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      final deleteButtonFinder = find.widgetWithText(TextButton, 'Delete');
      expect(tester.widget<TextButton>(deleteButtonFinder).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle();

      verify(
        () => profileBloc.add(any(that: isA<DeleteAccountEvent>())),
      ).called(1);
    },
  );
```

- [ ] **Step 3: Run the affected tests**

Run: `cd /home/ngigi/Documents/projects/farmTracker/frontend && flutter test test/features/profile/presentation/widgets/typed_delete_account_dialog_test.dart test/features/farm/presentation/pages/settings_page_test.dart`
Expected: PASS (4 tests total: 2 dialog tests + 2 settings-page tests).

- [ ] **Step 4: Static analysis**

Run: `cd /home/ngigi/Documents/projects/farmTracker/frontend && flutter analyze lib/features/profile lib/features/farm/presentation/pages/settings_page.dart lib/injection_container.dart test/features/profile test/features/farm/presentation/pages/settings_page_test.dart`
Expected: `No issues found!`

- [ ] **Step 5: Stage and commit only the feature-relevant files**

```bash
cd /home/ngigi/Documents/projects/farmTracker/frontend
git add \
  lib/features/profile/data/datasources/profile_remote_data_source.dart \
  lib/features/profile/data/repositories/profile_repository_impl.dart \
  lib/features/profile/domain/repositories/profile_repository.dart \
  lib/features/profile/domain/usecases/delete_account.dart \
  lib/features/profile/presentation/bloc/profile_bloc.dart \
  lib/features/profile/presentation/bloc/profile_event.dart \
  lib/features/profile/presentation/bloc/profile_state.dart \
  lib/injection_container.dart \
  lib/features/farm/presentation/pages/settings_page.dart \
  test/features/farm/presentation/pages/settings_page_test.dart
git commit -m "feat: wire typed-confirmation delete-account flow into Settings"
```

- [ ] **Step 6: Confirm unrelated changes were left out**

Run: `cd /home/ngigi/Documents/projects/farmTracker/frontend && git status`
Expected: `.github/workflows/release.yml`, `lib/features/auth/presentation/pages/onboarding_page.dart`, and `pubspec.lock` still listed as modified (not staged/committed), and `docs/play-store/` and `support/` still listed as untracked.

---

## Post-plan manual check

Not automatable in this environment (no running backend/emulator wired up here): start the backend (`make run` in the backend repo) and the Flutter app against it, sign in, open Settings → Danger Zone → Delete Account, confirm the dialog blocks submission until "DELETE" is typed, confirm deletion logs the session out, and confirm re-login with the same credentials fails (account and data are actually gone). Worth doing once before treating this as fully verified end-to-end.
