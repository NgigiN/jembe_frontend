import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';

class AnimalModel extends Animal implements SyncableModel {
  const AnimalModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.animalTypeId,
    required super.herdId,
    required super.birthDate,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.sex,
    super.acquisitionSource,
  });

  factory AnimalModel.create({
    required String userId,
    required String name,
    required String animalTypeId,
    required String herdId,
    required DateTime birthDate,
    String? sex,
    String? acquisitionSource,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return AnimalModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      name: name,
      // TODO(P4): unsynced/clientUuid-parent FK reconciliation — translate
      // parent clientUuid→server id + parent-before-child ordering before
      // push. P3 supports create under an ALREADY-SYNCED parent only.
      animalTypeId: animalTypeId,
      herdId: herdId,
      birthDate: birthDate,
      sex: sex,
      acquisitionSource: acquisitionSource,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    final sexValue = json['Sex'] ?? json['sex'];
    final acquisitionSourceValue =
        json['AcquisitionSource'] ?? json['acquisition_source'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return AnimalModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      animalTypeId: (json['animal_type_id'] ?? json['AnimalTypeID'] ?? '').toString(),
      herdId: (json['herd_id'] ?? json['HerdID'] ?? '').toString(),
      birthDate: _parseDate(json['birth_date'] ?? json['BirthDate']),
      sex: sexValue?.toString(),
      acquisitionSource: acquisitionSourceValue?.toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`AnimalSyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [AnimalModel].
  factory AnimalModel.fromDrift(AnimalRow row) {
    return AnimalModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      name: row.name,
      animalTypeId: row.animalTypeId,
      herdId: row.herdId,
      birthDate: row.birthDate,
      sex: row.sex,
      acquisitionSource: row.acquisitionSource,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this animal before (and independently of) the server-assigned
  /// [Animal.id]. Lives on the data model only — the domain `Animal` entity
  /// stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Animal.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `AnimalLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
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
      // TODO(P4): unsynced/clientUuid-parent FK reconciliation — translate
      // parent clientUuid→server id + parent-before-child ordering before
      // push. P3 supports create under an ALREADY-SYNCED parent only.
      'animal_type_id': int.tryParse(animalTypeId) ?? animalTypeId,
      'herd_id': int.tryParse(herdId) ?? herdId,
      'birth_date': birthDate.toUtc().toIso8601String(),
      'sex': sex,
      'acquisition_source': acquisitionSource,
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Animals` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  AnimalsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return AnimalsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      animalTypeId: Value(animalTypeId),
      herdId: Value(herdId),
      birthDate: Value(birthDate),
      sex: Value(sex),
      acquisitionSource: Value(acquisitionSource),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto AnimalModel's existing fields (the server id
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
  AnimalModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return AnimalModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      name: name,
      animalTypeId: animalTypeId,
      herdId: herdId,
      birthDate: birthDate,
      sex: sex,
      acquisitionSource: acquisitionSource,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
