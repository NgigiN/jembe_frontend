import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';

/// Rehydrates a model from a local drift row. The row's nullable
/// `serverId` becomes the model's `id` when present, else `''` (mirroring
/// the server-unknown placeholder used by `.create()`).
///
/// Carries over the row's local sync-state flags
/// ([CostCategoryModel.pending], [CostCategoryModel.deletedLocally]) —
/// `CostCategorySyncer` needs them to decide what survives a pull's full
/// re-fetch. The row's `created_at`/`updated_at` columns are deliberately
/// NOT carried over — see `CostCategoryModel`'s class docs: they are
/// synthesized fresh wherever needed, never round-tripped.
///
/// Split out of `cost_category_model.dart` (web-console Task 5.6) so the
/// model class itself never imports `app_database.dart` — only mobile-only
/// local data sources import this file directly; the web console's DI
/// container never reaches it.
CostCategoryModel costCategoryModelFromDrift(CostCategoryRow row) {
  return CostCategoryModel(
    id: row.serverId ?? '',
    clientUuid: row.clientUuid,
    name: row.name,
    type: row.type,
    category: row.category,
    isDefault: row.isDefault,
    pending: row.pending,
    deletedLocally: row.deletedLocally,
  );
}

/// Converts a [CostCategoryModel] into a drift insert/update companion for
/// the `CostCategories` table. `serverId` is `null` while the server hasn't
/// assigned an `id` yet (i.e. `id` is empty). `createdAt`/`updatedAt` are
/// synthesized fresh here (see `CostCategoryModel`'s class docs) — this
/// entity has no real timestamps to preserve.
extension CostCategoryModelDriftX on CostCategoryModel {
  CostCategoriesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
    int farmId = 1,
  }) {
    final now = DateTime.now();
    return CostCategoriesCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      name: Value(name),
      type: Value(type),
      category: Value(category),
      isDefault: Value(isDefault),
      createdAt: Value(now),
      updatedAt: Value(now),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
      farmId: Value(farmId),
    );
  }
}
