import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal_type.dart';

class AnimalTypeModel extends AnimalType implements SyncableModel {
  const AnimalTypeModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.notes,
  });
  factory AnimalTypeModel.create({
    required String userId,
    required String name,
    String? notes,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return AnimalTypeModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      name: name,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AnimalTypeModel.fromJson(Map<String, dynamic> json) {
    final notesValue = json['notes'] ?? json['Notes'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return AnimalTypeModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      notes: notesValue?.toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`AnimalTypeSyncer`) needs them
  /// to decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [AnimalTypeModel].
  factory AnimalTypeModel.fromDrift(AnimalTypeRow row) {
    return AnimalTypeModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      name: row.name,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this animal type before (and independently of) the
  /// server-assigned [AnimalType.id]. Lives on the data model only — the
  /// domain `AnimalType` entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [AnimalType.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `AnimalTypeLocalDataSource.markDeleted`). Always `false` on a model
  /// built from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `AnimalTypes` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  AnimalTypesCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return AnimalTypesCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto AnimalTypeModel's existing fields (the server id
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
  AnimalTypeModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return AnimalTypeModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      name: name,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
