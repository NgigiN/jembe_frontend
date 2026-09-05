import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';

class InfrastructureModel extends Infrastructure implements SyncableModel {
  const InfrastructureModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.name,
    required super.location,
    required super.cost,
    required super.date,
    required super.notes,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
  });

  factory InfrastructureModel.create({
    required String userId,
    required String type,
    required String name,
    required String location,
    required double cost,
    required DateTime date,
    String? notes,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return InfrastructureModel(
      id: '',
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      type: type,
      name: name,
      location: location,
      cost: cost,
      date: date,
      notes: notes ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory InfrastructureModel.fromJson(Map<String, dynamic> json) {
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];
    return InfrastructureModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['user_id'] ?? json['UserID'] ?? '').toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      location: (json['location'] ?? json['Location'] ?? '').toString(),
      cost: _parseDouble(json['cost'] ?? json['Cost']),
      date: _parseDate(json['date'] ?? json['Date']),
      notes: (json['notes'] ?? json['Notes'] ?? '').toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`InfrastructureSyncer`) needs
  /// them to decide LWW / delete-wins outcomes on pull, since they otherwise
  /// only live on the drift row, not on a bare [InfrastructureModel].
  factory InfrastructureModel.fromDrift(InfrastructureRow row) {
    return InfrastructureModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      type: row.type,
      name: row.name,
      location: row.location,
      cost: row.cost,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this infrastructure row before (and independently of) the
  /// server-assigned [Infrastructure.id]. Lives on the data model only — the
  /// domain `Infrastructure` entity stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Infrastructure.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `InfrastructureLocalDataSource.markDeleted`). Always `false` on a model
  /// built from a server response (`fromJson`) or `create`.
  final bool deletedLocally;

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'location': location,
      'cost': cost,
      'date': date.toUtc().toIso8601String(),
      'notes': notes,
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Infrastructures` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  InfrastructuresCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return InfrastructuresCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      type: Value(type),
      name: Value(name),
      location: Value(location),
      cost: Value(cost),
      date: Value(date),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }

  // --- SyncableModel: the read-only sync fields BaseEntitySyncer reads off
  // this model, mapped onto InfrastructureModel's existing fields (the
  // server id lives on `id`, blank until synced; the local flags on
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
  InfrastructureModel withSyncClientUuid(String clientUuid) {
    if (this.clientUuid == clientUuid) return this;
    return InfrastructureModel(
      id: id,
      clientUuid: clientUuid,
      userId: userId,
      type: type,
      name: name,
      location: location,
      cost: cost,
      date: date,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
