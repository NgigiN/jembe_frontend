// Unit tests for the generic [BaseEntitySyncer] at the base level, using a
// tiny fake [SyncableModel] + fake [RemoteSyncAdapter]/[LocalSyncStore] — no
// drift, no land. These prove the extracted push dispatch, pull loop, LWW /
// delete-wins reconciler, and the client_uuid ↔ server_id fallback are correct
// generically, so the 10 CRUD entities in P3 inherit tested behavior. The land
// pilot's own tests + the P2 e2e goldens separately prove the concrete `land`
// wiring is unchanged.
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/base_entity_syncer.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/core/sync/sync_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [SyncableModel] with just enough fields to exercise the base.
class _FakeModel implements SyncableModel {
  _FakeModel({
    required this.clientUuid,
    this.serverId = '',
    DateTime? updatedAt,
    this.pending = false,
    this.deletedLocally = false,
    this.name = 'row',
  }) : updatedAt = updatedAt ?? DateTime.utc(2026);

  final String clientUuid;
  final String serverId;
  final DateTime updatedAt;
  final bool pending;
  final bool deletedLocally;
  final String name;

  @override
  String get syncClientUuid => clientUuid;
  @override
  String get syncServerId => serverId;
  @override
  DateTime get syncUpdatedAt => updatedAt;
  @override
  bool get syncPending => pending;
  @override
  bool get syncDeletedLocally => deletedLocally;

  @override
  _FakeModel withSyncClientUuid(String clientUuid) {
    if (clientUuid == this.clientUuid) return this;
    return _FakeModel(
      clientUuid: clientUuid,
      serverId: serverId,
      updatedAt: updatedAt,
      name: name,
    );
  }

  _FakeModel copyWith({bool? pending}) => _FakeModel(
    clientUuid: clientUuid,
    serverId: serverId,
    updatedAt: updatedAt,
    pending: pending ?? this.pending,
    deletedLocally: deletedLocally,
    name: name,
  );
}

/// Records every call so tests assert exactly what the syncer sent; lets a
/// test inject a canned response or a thrown exception per method.
class _FakeRemote implements RemoteSyncAdapter<_FakeModel> {
  final List<_FakeModel> addCalls = [];
  final List<_FakeModel> updateCalls = [];
  final List<String> deleteCalls = [];
  final List<DateTime?> getSinceCalls = [];

  _FakeModel Function(_FakeModel sent)? onAdd;
  _FakeModel Function(_FakeModel sent)? onUpdate;
  List<_FakeModel> Function(DateTime? since)? onGetSince;
  Exception? throwOnAdd;
  Exception? throwOnGetSince;

  @override
  Future<_FakeModel> add(_FakeModel model) async {
    addCalls.add(model);
    if (throwOnAdd != null) throw throwOnAdd!;
    return (onAdd ?? (m) => m)(model);
  }

  @override
  Future<_FakeModel> update(_FakeModel model) async {
    updateCalls.add(model);
    return (onUpdate ?? (m) => m)(model);
  }

  @override
  Future<void> delete(String serverId) async {
    deleteCalls.add(serverId);
  }

  @override
  Future<List<_FakeModel>> getSince(DateTime? since) async {
    getSinceCalls.add(since);
    if (throwOnGetSince != null) throw throwOnGetSince!;
    return (onGetSince ?? (_) => const <_FakeModel>[])(since);
  }
}

/// In-memory local mirror keyed by client uuid, mirroring the real store's
/// contract: `upsert` writes the given `pending` flag onto the stored row, and
/// `setServerId` clears pending.
class _FakeLocal implements LocalSyncStore<_FakeModel> {
  final Map<String, _FakeModel> byClientUuid = {};

  @override
  Future<_FakeModel?> getByClientUuid(String clientUuid) async =>
      byClientUuid[clientUuid];

  @override
  Future<_FakeModel?> getByServerId(String serverId) async {
    for (final m in byClientUuid.values) {
      if (m.serverId.isNotEmpty && m.serverId == serverId) return m;
    }
    return null;
  }

  @override
  Future<void> upsert(_FakeModel model, {required bool pending}) async {
    byClientUuid[model.clientUuid] = model.copyWith(pending: pending);
  }

  @override
  Future<void> hardDelete(String clientUuid) async {
    byClientUuid.remove(clientUuid);
  }

  @override
  Future<void> setServerId(
    String clientUuid,
    String serverId,
    DateTime updatedAt,
  ) async {
    final existing = byClientUuid[clientUuid];
    if (existing == null) return;
    byClientUuid[clientUuid] = _FakeModel(
      clientUuid: clientUuid,
      serverId: serverId,
      updatedAt: updatedAt,
      // pending defaults to false — setServerId clears the pending flag.
      deletedLocally: existing.deletedLocally,
      name: existing.name,
    );
  }

  // Not exercised by these base-syncer tests (the syncer never calls it) —
  // added only so this fake keeps satisfying `LocalSyncStore` now that it
  // carries `markDeleted` (R1).
  @override
  Future<void> markDeleted(String clientUuid) async {
    final existing = byClientUuid[clientUuid];
    if (existing == null) return;
    byClientUuid[clientUuid] = _FakeModel(
      clientUuid: clientUuid,
      serverId: existing.serverId,
      updatedAt: existing.updatedAt,
      pending: true,
      deletedLocally: true,
      name: existing.name,
    );
  }
}

OutboxRow _entry({required String op, required String clientUuid}) {
  return OutboxRow(
    seq: 1,
    entity: 'fake',
    op: op,
    clientUuid: clientUuid,
    attempts: 0,
    state: 'pending',
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  late _FakeRemote remote;
  late _FakeLocal local;
  late BaseEntitySyncer<_FakeModel> syncer;

  setUp(() {
    remote = _FakeRemote();
    local = _FakeLocal();
    syncer = BaseEntitySyncer<_FakeModel>(
      entity: 'fake',
      remote: remote,
      local: local,
    );
  });

  test('exposes the entity tag it was constructed with', () {
    expect(syncer.entity, 'fake');
  });

  group('push — create', () {
    test('calls add and reconciles the server id + clears pending', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        pending: true,
      );
      remote.onAdd = (sent) => _FakeModel(
        clientUuid: sent.clientUuid,
        serverId: 'server-1',
        updatedAt: DateTime.utc(2026, 2),
      );

      await syncer.push(
        _entry(op: 'create', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.addCalls, hasLength(1));
      expect(remote.addCalls.single.clientUuid, 'cu-1');
      final row = local.byClientUuid['cu-1']!;
      expect(row.serverId, 'server-1');
      expect(row.pending, isFalse);
    });

    test('is a no-op when the local row is gone (annihilated)', () async {
      await syncer.push(
        _entry(op: 'create', clientUuid: 'missing'),
        FkResolver(const {}),
      );
      expect(remote.addCalls, isEmpty);
    });

    test(
      'idempotent retry: same server row twice does not duplicate',
      () async {
        local.byClientUuid['cu-1'] = _FakeModel(
          clientUuid: 'cu-1',
          pending: true,
        );
        remote.onAdd = (sent) => _FakeModel(
          clientUuid: 'cu-1',
          serverId: 'server-1',
          updatedAt: DateTime.utc(2026, 2),
        );

        await syncer.push(
          _entry(op: 'create', clientUuid: 'cu-1'),
          FkResolver(const {}),
        );
        await syncer.push(
          _entry(op: 'create', clientUuid: 'cu-1'),
          FkResolver(const {}),
        );

        expect(remote.addCalls, hasLength(2));
        expect(local.byClientUuid, hasLength(1));
        expect(local.byClientUuid['cu-1']!.serverId, 'server-1');
      },
    );

    test('a NetworkException from add propagates (not swallowed)', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        pending: true,
      );
      remote.throwOnAdd = NetworkException();

      await expectLater(
        syncer.push(
          _entry(op: 'create', clientUuid: 'cu-1'),
          FkResolver(const {}),
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a ServerException from add propagates (not swallowed)', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        pending: true,
      );
      remote.throwOnAdd = const ServerException('bad request');

      await expectLater(
        syncer.push(
          _entry(op: 'create', clientUuid: 'cu-1'),
          FkResolver(const {}),
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('applies the resolveFks translator before add and records the new '
        'id', () async {
      local.byClientUuid['c1'] = _FakeModel(clientUuid: 'c1', pending: true);
      remote.onAdd = (sent) => _FakeModel(
        clientUuid: sent.clientUuid,
        serverId: '99',
        updatedAt: DateTime.utc(2026, 2),
      );
      var translated = false;
      final translatingSyncer = BaseEntitySyncer<_FakeModel>(
        entity: 'thing',
        remote: remote,
        local: local,
        resolveFks: (m, r) async {
          translated = true;
          return m;
        },
      );
      final resolver = FkResolver(const {});

      await translatingSyncer.push(
        _entry(op: 'create', clientUuid: 'c1'),
        resolver,
      );

      expect(translated, isTrue);
      expect(await resolver.resolve('thing', 'c1'), '99');
    });
  });

  group('push — update', () {
    test('calls update for an already-synced row and reconciles', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        pending: true,
        name: 'New name',
      );
      remote.onUpdate = (sent) => _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        updatedAt: DateTime.utc(2026, 3),
        name: sent.name,
      );

      await syncer.push(
        _entry(op: 'update', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.updateCalls, hasLength(1));
      expect(remote.updateCalls.single.serverId, 'server-1');
      expect(remote.addCalls, isEmpty);
      expect(local.byClientUuid['cu-1']!.pending, isFalse);
    });

    test('falls back to create when the row has no server id', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        pending: true,
      );
      remote.onAdd = (sent) => _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-9',
        updatedAt: DateTime.utc(2026, 4),
      );

      await syncer.push(
        _entry(op: 'update', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.addCalls, hasLength(1));
      expect(remote.updateCalls, isEmpty);
      expect(local.byClientUuid['cu-1']!.serverId, 'server-9');
    });
  });

  group('push — delete', () {
    test('calls delete with the server id then hard-deletes locally', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
      );

      await syncer.push(
        _entry(op: 'delete', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.deleteCalls, ['server-1']);
      expect(local.byClientUuid.containsKey('cu-1'), isFalse);
    });

    test('a never-synced row (no server id) is just hard-deleted', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        pending: true,
      );

      await syncer.push(
        _entry(op: 'delete', clientUuid: 'cu-1'),
        FkResolver(const {}),
      );

      expect(remote.deleteCalls, isEmpty);
      expect(local.byClientUuid.containsKey('cu-1'), isFalse);
    });

    test('is a no-op when the local row is already gone', () async {
      await syncer.push(
        _entry(op: 'delete', clientUuid: 'missing'),
        FkResolver(const {}),
      );
      expect(remote.deleteCalls, isEmpty);
    });
  });

  group('pull', () {
    test(
      'upserts a changed server row and returns the max updatedAt',
      () async {
        remote.onGetSince = (since) => [
          _FakeModel(
            clientUuid: 'cu-1',
            serverId: 'server-1',
            updatedAt: DateTime.utc(2026, 5),
          ),
        ];

        final cursor = await syncer.pull(null);

        expect(remote.getSinceCalls, [null]);
        expect(cursor!.isAtSameMomentAs(DateTime.utc(2026, 5)), isTrue);
        final row = local.byClientUuid['cu-1']!;
        expect(row.serverId, 'server-1');
        expect(row.pending, isFalse);
      },
    );

    test('passes the cursor through as getSince argument', () async {
      final since = DateTime.utc(2026);
      await syncer.pull(since);
      expect(remote.getSinceCalls, [since]);
    });

    test('returns null and touches nothing when nothing changed', () async {
      final cursor = await syncer.pull(DateTime.utc(2026));
      expect(cursor, isNull);
      expect(local.byClientUuid, isEmpty);
    });

    test('returns the MAX updatedAt across multiple server rows', () async {
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: 'cu-1',
          serverId: 's-1',
          updatedAt: DateTime.utc(2026),
        ),
        _FakeModel(
          clientUuid: 'cu-2',
          serverId: 's-2',
          updatedAt: DateTime.utc(2026, 6),
        ),
        _FakeModel(
          clientUuid: 'cu-3',
          serverId: 's-3',
          updatedAt: DateTime.utc(2026, 3),
        ),
      ];

      final cursor = await syncer.pull(null);

      expect(cursor!.isAtSameMomentAs(DateTime.utc(2026, 6)), isTrue);
    });

    test('falls back to matching by server id when server row has no '
        'client_uuid', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        name: 'Old name',
      );
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: '',
          serverId: 'server-1',
          name: 'Server name',
          updatedAt: DateTime.utc(2026, 7),
        ),
      ];

      await syncer.pull(null);

      // Written back under the LOCAL client uuid, not a stray blank-keyed row.
      expect(local.byClientUuid.containsKey(''), isFalse);
      expect(local.byClientUuid['cu-1']!.name, 'Server name');
    });

    test('skips a server row that can be keyed neither way', () async {
      remote.onGetSince = (since) => [
        _FakeModel(clientUuid: '', updatedAt: DateTime.utc(2026, 7)),
      ];

      await syncer.pull(null);

      expect(local.byClientUuid, isEmpty);
    });

    test(
      'LWW: a pending local edit NEWER than the server row is kept',
      () async {
        local.byClientUuid['cu-1'] = _FakeModel(
          clientUuid: 'cu-1',
          serverId: 'server-1',
          name: 'Local edit',
          updatedAt: DateTime.utc(2026, 8),
          pending: true,
        );
        remote.onGetSince = (since) => [
          _FakeModel(
            clientUuid: 'cu-1',
            serverId: 'server-1',
            name: 'Stale server value',
            updatedAt: DateTime.utc(2026, 6),
          ),
        ];

        await syncer.pull(null);

        final row = local.byClientUuid['cu-1']!;
        expect(row.name, 'Local edit');
        expect(row.pending, isTrue);
      },
    );

    test('LWW: a NEWER server row overwrites a pending local edit', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        name: 'Local edit',
        updatedAt: DateTime.utc(2026, 6),
        pending: true,
      );
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: 'cu-1',
          serverId: 'server-1',
          name: 'Newer server value',
          updatedAt: DateTime.utc(2026, 8),
        ),
      ];

      await syncer.pull(null);

      final row = local.byClientUuid['cu-1']!;
      expect(row.name, 'Newer server value');
      expect(row.pending, isFalse);
    });

    test('LWW is strict isAfter: an EQUAL-instant server row does NOT '
        'overwrite a pending local edit', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        name: 'Local edit',
        updatedAt: DateTime.utc(2026, 6),
        pending: true,
      );
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: 'cu-1',
          serverId: 'server-1',
          name: 'Server value same instant',
          updatedAt: DateTime.utc(2026, 6),
        ),
      ];

      await syncer.pull(null);

      final row = local.byClientUuid['cu-1']!;
      expect(row.name, 'Local edit');
      expect(row.pending, isTrue);
    });

    test('delete-wins: does not resurrect a pending local delete', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        deletedLocally: true,
        pending: true,
      );
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: 'cu-1',
          serverId: 'server-1',
          updatedAt: DateTime.utc(2026, 9),
        ),
      ];

      await syncer.pull(null);

      final row = local.byClientUuid['cu-1']!;
      expect(row.deletedLocally, isTrue);
      expect(row.pending, isTrue);
    });

    test('a clean (not pending) local row is overwritten outright', () async {
      local.byClientUuid['cu-1'] = _FakeModel(
        clientUuid: 'cu-1',
        serverId: 'server-1',
        name: 'Old',
        updatedAt: DateTime.utc(2026, 10),
      );
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: 'cu-1',
          serverId: 'server-1',
          name: 'New',
          updatedAt: DateTime.utc(2026),
        ),
      ];

      await syncer.pull(null);

      expect(local.byClientUuid['cu-1']!.name, 'New');
    });

    test('a new server row with no local match is inserted', () async {
      remote.onGetSince = (since) => [
        _FakeModel(
          clientUuid: 'cu-new',
          serverId: 'server-1',
          name: 'Fresh',
          updatedAt: DateTime.utc(2026, 5),
        ),
      ];

      await syncer.pull(null);

      expect(local.byClientUuid['cu-new']!.name, 'Fresh');
      expect(local.byClientUuid['cu-new']!.pending, isFalse);
    });

    test(
      'a NetworkException from getSince propagates (not swallowed)',
      () async {
        remote.throwOnGetSince = NetworkException();
        await expectLater(syncer.pull(null), throwsA(isA<NetworkException>()));
      },
    );

    test(
      'a ServerException from getSince propagates (not swallowed)',
      () async {
        remote.throwOnGetSince = const ServerException('boom');
        await expectLater(syncer.pull(null), throwsA(isA<ServerException>()));
      },
    );
  });
}
