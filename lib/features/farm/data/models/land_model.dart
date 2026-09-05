import 'package:drift/drift.dart' show Value;
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/util/uuid_gen.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';

class LandModel extends Land {
  const LandModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    this.clientUuid = '',
    this.pending = false,
    this.deletedLocally = false,
    super.size,
    super.location,
    super.soilType,
    super.tenureType,
  });

  factory LandModel.create({
    required String userId,
    required String name,
    double? size,
    String? location,
    String? soilType,
    String? tenureType,
    String? clientUuid,
    UuidGen uuid = const UuidGen(),
  }) {
    final now = DateTime.now();
    return LandModel(
      id: '', // Will be set by the server
      clientUuid: clientUuid ?? uuid.v4(),
      userId: userId,
      name: name,
      size: size,
      location: location,
      soilType: soilType,
      tenureType: tenureType,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory LandModel.fromJson(Map<String, dynamic> json) {
    final sizeValue = json['Size'] ?? json['size'];
    final locationValue = json['Location'] ?? json['location'];
    final soilTypeValue = json['SoilType'] ?? json['soil_type'];
    final tenureTypeValue = json['TenureType'] ?? json['tenure_type'];
    final clientUuidValue = json['ClientUUID'] ?? json['client_uuid'];

    return LandModel(
      id: (json['ID'] ?? json['id'] ?? '').toString(),
      clientUuid: (clientUuidValue ?? '').toString(),
      userId: (json['UserID'] ?? json['user_id'] ?? '').toString(),
      name: (json['Name'] ?? json['name'] ?? '').toString(),
      size: sizeValue != null ? (sizeValue as num).toDouble() : null,
      location: locationValue?.toString(),
      soilType: soilTypeValue?.toString(),
      tenureType: tenureTypeValue?.toString(),
      createdAt: _parseDate(json['CreatedAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['UpdatedAt'] ?? json['updated_at']),
    );
  }

  /// Rehydrates a model from a local drift row. The row's nullable
  /// `serverId` becomes the model's `id` when present, else `''`
  /// (mirroring the server-unknown placeholder used by `.create()`).
  ///
  /// Also carries over the row's local sync-state flags ([pending],
  /// [deletedLocally]) — the sync pipeline (`LandSyncer`) needs them to
  /// decide LWW / delete-wins outcomes on pull, since they otherwise only
  /// live on the drift row, not on a bare [LandModel].
  factory LandModel.fromDrift(LandRow row) {
    return LandModel(
      id: row.serverId ?? '',
      clientUuid: row.clientUuid,
      userId: row.userId,
      name: row.name,
      size: row.size,
      location: row.location,
      soilType: row.soilType,
      tenureType: row.tenureType,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      pending: row.pending,
      deletedLocally: row.deletedLocally,
    );
  }

  /// Local-only identity used by the offline outbox/pull pipeline to
  /// track this land before (and independently of) the server-assigned
  /// [Land.id]. Lives on the data model only — the domain `Land` entity
  /// stays unaware of sync plumbing.
  final String clientUuid;

  /// Mirrors the drift row's `pending` column: true while this row has a
  /// local mutation not yet acknowledged by the server. Always `false` on a
  /// model built from a server response (`fromJson`) or `create` — those
  /// have no local sync state to report. Excluded from [Land.props]
  /// (equality), like [clientUuid] and [deletedLocally].
  final bool pending;

  /// Mirrors the drift row's `deletedLocally` column: true while this row
  /// is a tombstone awaiting delete-sync (see
  /// `LandLocalDataSource.markDeleted`). Always `false` on a model built
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
      'id': id,
      'client_uuid': clientUuid,
      'user_id': userId,
      'name': name,
      'size': size,
      'location': location,
      'soil_type': soilType,
      'tenure_type': tenureType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts this model into a drift insert/update companion for the
  /// `Lands` table. `serverId` is `null` while the server hasn't
  /// assigned an `id` yet (i.e. `id` is empty).
  LandsCompanion toCompanion({
    required bool pending,
    bool deletedLocally = false,
  }) {
    return LandsCompanion(
      clientUuid: Value(clientUuid),
      serverId: Value(id.isEmpty ? null : id),
      userId: Value(userId),
      name: Value(name),
      size: Value(size),
      location: Value(location),
      soilType: Value(soilType),
      tenureType: Value(tenureType),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      deletedLocally: Value(deletedLocally),
    );
  }
}
