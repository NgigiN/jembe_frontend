import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/core/utils/json_parsing.dart';
import 'package:farm_tracker/features/farm/domain/entities/herd.dart';

class HerdModel extends Herd implements SyncableModel {
  const HerdModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.animalTypeId,
    required super.location,
    required super.initialHeadCount,
    required super.currentHeadCount,
    required super.startDate,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.endDate,
  });
  factory HerdModel.create({
    required String userId,
    required String name,
    required String animalTypeId,
    required String location,
    required int initialHeadCount,
    required DateTime startDate,
    DateTime? endDate,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return HerdModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      name: name,
      // animalTypeId may hold an unsynced parent's client_uuid here; the
      // syncer's `translateHerdFks` (fk_translators.dart) resolves it to the
      // parent's server id at push time via `BaseEntitySyncer.resolveFks`.
      animalTypeId: animalTypeId,
      location: location,
      initialHeadCount: initialHeadCount,
      currentHeadCount: initialHeadCount,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory HerdModel.fromJson(Map<String, dynamic> json) {
    final endDateValue = json['end_date'] ?? json['EndDate'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];
    return HerdModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      animalTypeId: (json['animal_type_id'] ?? json['AnimalTypeID'] ?? '')
          .toString(),
      location: (json['location'] ?? json['Location'] ?? '').toString(),
      initialHeadCount: parseInt(
        json['initial_head_count'] ?? json['InitialHeadCount'],
      ),
      currentHeadCount: parseInt(
        json['current_head_count'] ?? json['CurrentHeadCount'],
      ),
      startDate: parseDate(json['start_date'] ?? json['StartDate']),
      endDate: endDateValue != null && endDateValue.toString().isNotEmpty
          ? parseDate(endDateValue)
          : null,
      createdAt: parseDate(dualKey(json, 'created_at')),
      updatedAt: parseDate(dualKey(json, 'updated_at')),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`HerdSyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [HerdModel].
  factory HerdModel.fromDrift(HerdRow row) {
    return HerdModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      name: row.name,
      animalTypeId: row.animalTypeId,
      location: row.location,
      initialHeadCount: row.initialHeadCount,
      currentHeadCount: row.currentHeadCount,
      startDate: row.startDate,
      endDate: row.endDate,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this herd before (and independently of) the server-assigned
  /// [Herd.id]. Lives on the data model only — the domain `Herd` entity
  /// stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Herd.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `HerdLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      // animalTypeId may hold an unsynced parent's client_uuid here; the
      // syncer's `translateHerdFks` (fk_translators.dart) resolves it to the
      // parent's server id at push time via `BaseEntitySyncer.resolveFks`.
      'animal_type_id': int.tryParse(animalTypeId) ?? animalTypeId,
      'location': location,
      'initial_head_count': initialHeadCount,
      // `current_head_count` is server-managed and intentionally OMITTED
      // here — preserved from the pre-offline wire body.
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Herds` table. `serverId` is `null` while the server hasn't assigned an
  /// `id` yet (i.e. `id` is empty). Unlike [toJson] (the wire body, which
  /// omits the server-managed `current_head_count`), the local mirror DOES
  /// track [currentHeadCount] — it's a real domain field the app reads.
  HerdsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return HerdsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      animalTypeId: Value(animalTypeId),
      location: Value(location),
      initialHeadCount: Value(initialHeadCount),
      currentHeadCount: Value(currentHeadCount),
      startDate: Value(startDate),
      endDate: Value(endDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto HerdModel's existing fields (the server id
  // lives on `id`, blank until synced; the local flags on
  // `pending`/`deletedLocally`).
  @override
  String get syncClientUuid => clientUuid;

  @override
  String get syncServerId => id;

  @override
  DateTime get syncUpdatedAt => updatedAt;

  @override
  bool get syncPending => pending;

  @override
  bool get syncDeletedLocally => deletedLocally;

  /// Returns this model with [clientUuid] substituted, every other field
  /// untouched — or `this` unchanged when it already carries [clientUuid]. Used
  /// by the pull reconciler to re-key a server row under the local row's client
  /// uuid before upserting. Mirrors `LandModel.withSyncClientUuid` verbatim:
  /// the copy carries no local sync flags (they default `false`), which is
  /// exactly how the pulled server row is always upserted.
  @override
  HerdModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return HerdModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      name: name,
      animalTypeId: animalTypeId,
      location: location,
      initialHeadCount: initialHeadCount,
      currentHeadCount: currentHeadCount,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Returns a copy with the given FK fields overridden (each `null` arg keeps
  /// the current value), every other field untouched. Used by the P4 sync FK
  /// translator to substitute a parent's server id for its client_uuid before
  /// push. Reconstruct via the SAME constructor `withSyncClientUuid` uses.
  HerdModel withResolvedFks({String? animalTypeId}) {
    return HerdModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      name: name,
      animalTypeId: animalTypeId ?? this.animalTypeId,
      location: location,
      initialHeadCount: initialHeadCount,
      currentHeadCount: currentHeadCount,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
