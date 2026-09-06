import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal SyncableModel carrying only the server id the resolver reads.
class _P implements SyncableModel {
  _P(this.clientUuid, this.serverId);
  final String clientUuid;
  final String serverId;
  @override
  String get syncClientUuid => clientUuid;
  @override
  String get syncServerId => serverId;
  @override
  DateTime get syncUpdatedAt => DateTime.utc(2026);
  @override
  bool get syncPending => false;
  @override
  bool get syncDeletedLocally => false;
  @override
  SyncableModel withSyncClientUuid(String clientUuid) => _P(clientUuid, serverId);
}

// A LocalSyncStore that only answers getByClientUuid from a seeded map.
class _Store implements LocalSyncStore<SyncableModel> {
  _Store(this._rows);
  final Map<String, _P> _rows;
  @override
  Future<SyncableModel?> getByClientUuid(String clientUuid) async => _rows[clientUuid];
  @override
  Future<SyncableModel?> getByServerId(String serverId) async => null;
  @override
  Future<void> upsert(SyncableModel model, {required bool pending}) async {}
  @override
  Future<void> hardDelete(String clientUuid) async {}
  @override
  Future<void> setServerId(String c, String s, DateTime u) async {}
  @override
  Future<void> markDeleted(String clientUuid) async {}
}

void main() {
  test('resolves from the in-pass map first', () async {
    final r = FkResolver({});
    r.record('herd', 'herd-uuid', '42');
    expect(await r.resolve('herd', 'herd-uuid'), '42');
  });

  test('falls back to the local store for a parent synced in a prior pass', () async {
    final r = FkResolver({'herd': _Store({'herd-uuid': _P('herd-uuid', '7')})});
    expect(await r.resolve('herd', 'herd-uuid'), '7');
  });

  test('returns null when the parent has no server id yet', () async {
    final r = FkResolver({'herd': _Store({'herd-uuid': _P('herd-uuid', '')})});
    expect(await r.resolve('herd', 'herd-uuid'), isNull);
  });

  test('returns null when the parent entity has no registered store', () async {
    final r = FkResolver({});
    expect(await r.resolve('herd', 'herd-uuid'), isNull);
  });
}
