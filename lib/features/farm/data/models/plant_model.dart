import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/core/utils/json_parsing.dart';
import 'package:farm_tracker/features/farm/domain/entities/plant.dart';

class PlantModel extends Plant implements SyncableModel {
  const PlantModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.variety,
  });

  factory PlantModel.create({
    required String userId,
    required String name,
    String? variety,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return PlantModel(
      id: '', // Will be set by the server
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      name: name,
      variety: variety,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    final varietyValue = json['Variety'] ?? json['variety'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return PlantModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      variety: varietyValue?.toString(),
      createdAt: parseDate(dualKey(json, 'created_at')),
      updatedAt: parseDate(dualKey(json, 'updated_at')),
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this plant before (and independently of) the server-assigned
  /// [Plant.id]. Lives on the data model only — the domain `Plant` entity
  /// stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Plant.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `PlantLocalDataSource.markDeleted`). Always `false` on a model built
  /// from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_uuid': clientUuid,
      'user_id': userId,
      'name': name,
      'variety': variety,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto PlantModel's existing fields (the server id lives
  // on `id`, blank until synced; the local flags on `pending`/`deletedLocally`).
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
  PlantModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return PlantModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      name: name,
      variety: variety,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
