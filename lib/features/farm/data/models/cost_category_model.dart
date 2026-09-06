import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/cost_category.dart';

/// Data model for the `cost_category` offline outlier.
///
/// Unlike every other P3 entity, [CostCategory] has NO `userId` and NO
/// timestamps of its own — the server's create endpoint returns a bare
/// `bool` (not the created row), so there is no server id or `updatedAt` to
/// reconcile a create against. That rules out `BaseEntitySyncer`'s
/// last-writer-wins pull reconciler (which needs a real `updatedAt` to
/// compare instants) — this entity is driven by the bespoke
/// `CostCategorySyncer` instead: a read-through cache that does a FULL
/// re-fetch on every pull rather than an `updatedSince` delta.
///
/// [createdAt]/[updatedAt] below are therefore SYNTHETIC: `DateTime.now()`
/// minted fresh wherever a value is needed (`toCompanion`, [syncUpdatedAt]),
/// never carried from the drift row and never read back from the server.
/// They exist purely to satisfy the drift table's uniform sync-header
/// schema (every offline-mirrored table has `created_at`/`updated_at`
/// columns) and [SyncableModel]'s contract — `CostCategorySyncer` never
/// looks at them for LWW.
class CostCategoryModel extends CostCategory implements SyncableModel {
  const CostCategoryModel({
    required super.id,
    required super.name,
    required super.type,
    required super.category,
    required super.isDefault,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
  });

  factory CostCategoryModel.create({
    required String name,
    required String type,
    required String category,
    bool isDefault = false,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    return CostCategoryModel(
      id: '', // Server-unknown placeholder — this entity's create returns
      // only a bool, so the server id is never learned here; a later pull's
      // full re-fetch assigns it (see `CostCategorySyncer.pull`).
      clientUuid: clientUuid ?? uuid.v4(),
      name: name,
      type: type,
      category: category,
      isDefault: isDefault,
    );
  }

  factory CostCategoryModel.fromJson(Map<String, dynamic> json) {
    return CostCategoryModel(
      id: (json['id'] ?? json['ID'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      category: (json['category'] ?? json['Category'] ?? '').toString(),
      isDefault:
          (json['is_default'] as bool?) ??
          (json['isDefault'] as bool?) ??
          false,
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''` (mirroring
  /// the server-unknown placeholder used by `.create()`).
  ///
  /// Carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — `CostCategorySyncer` needs them to decide what
  /// survives a pull's full re-fetch. The row's `created_at`/`updated_at`
  /// columns are deliberately NOT carried over — see class docs: they are
  /// synthesized fresh wherever needed, never round-tripped.
  factory CostCategoryModel.fromDrift(CostCategoryRow row) {
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

  /// Local-only identity used by the offline outbox/pull pipeline to track
  /// this category before (and independently of) the server-assigned
  /// [CostCategory.id]. Lives on the data model only — the domain
  /// `CostCategory` entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [CostCategory.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `CostCategoryLocalDataSource.markDeleted`). Always `false` on a model
  /// built from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  /// Wire body — preserved VERBATIM from the pre-offline model (same 5
  /// keys, same shape). Never carries `client_uuid`: the bespoke syncer's
  /// push adds that directly to the POST body it sends, so this entity's
  /// on-the-wire read/write shape is untouched by the offline rollout.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'category': category,
      'is_default': isDefault,
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `CostCategories` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty). `createdAt`/`updatedAt` are
  /// synthesized fresh here (see class docs) — this entity has no real
  /// timestamps to preserve.
  CostCategoriesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
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
    );
  }

  // --- SyncableModel: the read-only sync fields the offline pipeline reads
  // off this model. [syncUpdatedAt] is SYNTHETIC (see class docs) — never
  // read by `CostCategorySyncer` (no LWW for this entity); it exists only so
  // this class satisfies the shared [SyncableModel] contract.
  @override
  String get syncClientUuid => clientUuid;

  @override
  String get syncServerId => id;

  @override
  DateTime get syncUpdatedAt => DateTime.now();

  @override
  bool get syncPending => pending;

  @override
  bool get syncDeletedLocally => deletedLocally;

  /// Returns this model with [clientUuid] substituted, every other field
  /// untouched — or `this` unchanged when it already carries [clientUuid].
  /// Used by `CostCategorySyncer.pull` to re-key a server row (which never
  /// carries a client uuid of its own) under the deterministic `'srv:' +
  /// serverId` before upserting. The copy carries no local sync flags (they
  /// default `false`) — mirrors `LandModel.withSyncClientUuid` verbatim.
  @override
  CostCategoryModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return CostCategoryModel(
      id: id,
      clientUuid: clientUuid,
      name: name,
      type: type,
      category: category,
      isDefault: isDefault,
    );
  }
}
