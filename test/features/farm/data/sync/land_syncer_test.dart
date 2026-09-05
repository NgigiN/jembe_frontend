import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/sync/land_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controllable fake of [LandRemoteDataSource] — records every call so tests
/// can assert exactly what [LandSyncer] sent, and lets a test inject a
/// canned response or a thrown exception per method.
class _FakeLandRemoteDataSource implements LandRemoteDataSource {
  final List<LandModel> addCalls = [];
  final List<LandModel> updateCalls = [];
  final List<String> deleteCalls = [];
  final List<DateTime?> getLandsCalls = [];

  LandModel Function(LandModel sent)? onAdd;
  LandModel Function(LandModel sent)? onUpdate;
  List<LandModel> Function(DateTime? since)? onGetLands;
  Exception? throwOnAdd;
  Exception? throwOnGetLands;

  @override
  Future<LandModel> addLand(LandModel land) async {
    addCalls.add(land);
    if (throwOnAdd != null) throw throwOnAdd!;
    return (onAdd ?? (l) => l)(land);
  }

  @override
  Future<LandModel> updateLand(LandModel land) async {
    updateCalls.add(land);
    return (onUpdate ?? (l) => l)(land);
  }

  @override
  Future<void> deleteLand(String id) async {
    deleteCalls.add(id);
  }

  @override
  Future<List<LandModel>> getLands({DateTime? updatedSince}) async {
    getLandsCalls.add(updatedSince);
    if (throwOnGetLands != null) throw throwOnGetLands!;
    return (onGetLands ?? (_) => const <LandModel>[])(updatedSince);
  }
}

LandModel _land({
  required String clientUuid,
  String id = '',
  String name = 'North Field',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return LandModel(
    id: id,
    clientUuid: clientUuid,
    userId: 'user-1',
    name: name,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

OutboxRow _entry({
  required String op,
  required String clientUuid,
  int seq = 1,
}) {
  return OutboxRow(
    seq: seq,
    entity: 'land',
    op: op,
    clientUuid: clientUuid,
    attempts: 0,
    state: 'pending',
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  late AppDatabase db;
  late LandLocalDataSource local;
  late _FakeLandRemoteDataSource remote;
  late LandSyncer syncer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    local = LandLocalDataSource(db);
    remote = _FakeLandRemoteDataSource();
    syncer = LandSyncer(remote: remote, local: local);
  });

  tearDown(() async {
    await db.close();
  });

  test('entity is "land"', () {
    expect(syncer.entity, 'land');
  });

  group('push — create', () {
    test('calls addLand and reconciles the server id + clears pending', () async {
      await local.upsert(_land(clientUuid: 'cu-1'), pending: true);
      remote.onAdd = (sent) => _land(
        clientUuid: sent.clientUuid,
        id: 'server-1',
        name: sent.name,
        updatedAt: DateTime.utc(2026, 2),
      );

      await syncer.push(_entry(op: 'create', clientUuid: 'cu-1'));

      expect(remote.addCalls, hasLength(1));
      expect(remote.addCalls.single.clientUuid, 'cu-1');

      final row = await (db.select(
        db.lands,
      )..where((r) => r.clientUuid.equals('cu-1'))).getSingle();
      expect(row.serverId, 'server-1');
      expect(row.pending, isFalse);
    });

    test('is a no-op when the local row is gone (annihilated)', () async {
      await syncer.push(_entry(op: 'create', clientUuid: 'missing'));

      expect(remote.addCalls, isEmpty);
    });

    test('idempotent retry: addLand returning the same server row twice '
        'does not duplicate the local row', () async {
      await local.upsert(_land(clientUuid: 'cu-1'), pending: true);
      remote.onAdd = (sent) => _land(
        clientUuid: 'cu-1',
        id: 'server-1',
        updatedAt: DateTime.utc(2026, 2),
      );

      await syncer.push(_entry(op: 'create', clientUuid: 'cu-1'));
      // Simulate a retried push (e.g. the ack was lost after a successful
      // create) — P1 guarantees the SAME server row comes back.
      await syncer.push(_entry(op: 'create', clientUuid: 'cu-1'));

      expect(remote.addCalls, hasLength(2));
      final rows = await db.select(db.lands).get();
      expect(rows, hasLength(1));
      expect(rows.single.serverId, 'server-1');
    });

    test('a NetworkException from addLand propagates (not swallowed)', () async {
      await local.upsert(_land(clientUuid: 'cu-1'), pending: true);
      remote.throwOnAdd = NetworkException();

      await expectLater(
        syncer.push(_entry(op: 'create', clientUuid: 'cu-1')),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a ServerException from addLand propagates (not swallowed)', () async {
      await local.upsert(_land(clientUuid: 'cu-1'), pending: true);
      remote.throwOnAdd = const ServerException('bad request');

      await expectLater(
        syncer.push(_entry(op: 'create', clientUuid: 'cu-1')),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('push — update', () {
    test('calls updateLand for an already-synced row and reconciles', () async {
      await local.upsert(
        _land(clientUuid: 'cu-1', id: 'server-1', name: 'Old name'),
        pending: false,
      );
      await local.upsert(
        _land(clientUuid: 'cu-1', id: 'server-1', name: 'New name'),
        pending: true,
      );
      remote.onUpdate = (sent) => _land(
        clientUuid: 'cu-1',
        id: 'server-1',
        name: sent.name,
        updatedAt: DateTime.utc(2026, 3),
      );

      await syncer.push(_entry(op: 'update', clientUuid: 'cu-1'));

      expect(remote.updateCalls, hasLength(1));
      expect(remote.updateCalls.single.id, 'server-1');
      expect(remote.addCalls, isEmpty);

      final row = await (db.select(
        db.lands,
      )..where((r) => r.clientUuid.equals('cu-1'))).getSingle();
      expect(row.pending, isFalse);
      expect(row.name, 'New name');
    });

    test(
      'falls back to create when the local row has no server id (defensive)',
      () async {
        await local.upsert(_land(clientUuid: 'cu-1'), pending: true);
        remote.onAdd = (sent) =>
            _land(clientUuid: 'cu-1', id: 'server-9', updatedAt: DateTime.utc(2026, 4));

        await syncer.push(_entry(op: 'update', clientUuid: 'cu-1'));

        expect(remote.addCalls, hasLength(1));
        expect(remote.updateCalls, isEmpty);
        final row = await (db.select(
          db.lands,
        )..where((r) => r.clientUuid.equals('cu-1'))).getSingle();
        expect(row.serverId, 'server-9');
      },
    );
  });

  group('push — delete', () {
    test('calls deleteLand with the server id then hard-deletes locally', () async {
      await local.upsert(_land(clientUuid: 'cu-1', id: 'server-1'), pending: false);

      await syncer.push(_entry(op: 'delete', clientUuid: 'cu-1'));

      expect(remote.deleteCalls, ['server-1']);
      expect(await local.getByClientUuid('cu-1'), isNull);
    });

    test(
      'a row that never synced (no server id) is just hard-deleted locally',
      () async {
        await local.upsert(_land(clientUuid: 'cu-1'), pending: true);

        await syncer.push(_entry(op: 'delete', clientUuid: 'cu-1'));

        expect(remote.deleteCalls, isEmpty);
        expect(await local.getByClientUuid('cu-1'), isNull);
      },
    );

    test('is a no-op when the local row is already gone', () async {
      await syncer.push(_entry(op: 'delete', clientUuid: 'missing'));

      expect(remote.deleteCalls, isEmpty);
    });
  });

  group('pull', () {
    test('upserts a changed server row and returns the max updatedAt', () async {
      final serverRow = _land(
        clientUuid: 'cu-1',
        id: 'server-1',
        updatedAt: DateTime.utc(2026, 5),
      );
      remote.onGetLands = (since) => [serverRow];

      final cursor = await syncer.pull(null);

      expect(remote.getLandsCalls, [null]);
      expect(cursor, isNotNull);
      expect(cursor!.isAtSameMomentAs(DateTime.utc(2026, 5)), isTrue);

      final local1 = await local.getByClientUuid('cu-1');
      expect(local1, isNotNull);
      expect(local1!.id, 'server-1');
      expect(local1.pending, isFalse);
    });

    test('passes the cursor through as updatedSince', () async {
      final since = DateTime.utc(2026);

      await syncer.pull(since);

      expect(remote.getLandsCalls, [since]);
    });

    test('returns null and touches nothing when the server has no changes', () async {
      final cursor = await syncer.pull(DateTime.utc(2026));

      expect(cursor, isNull);
    });

    test('returns the MAX updatedAt across multiple server rows', () async {
      remote.onGetLands = (since) => [
        _land(clientUuid: 'cu-1', id: 's-1', updatedAt: DateTime.utc(2026)),
        _land(clientUuid: 'cu-2', id: 's-2', updatedAt: DateTime.utc(2026, 6)),
        _land(clientUuid: 'cu-3', id: 's-3', updatedAt: DateTime.utc(2026, 3)),
      ];

      final cursor = await syncer.pull(null);

      expect(cursor!.isAtSameMomentAs(DateTime.utc(2026, 6)), isTrue);
    });

    test(
      'falls back to matching by server id when the server row carries no '
      'client_uuid',
      () async {
        await local.upsert(
          _land(clientUuid: 'cu-1', id: 'server-1', name: 'Old name'),
          pending: false,
        );
        remote.onGetLands = (since) => [
          LandModel(
            id: 'server-1',
            clientUuid: '',
            userId: 'user-1',
            name: 'Server name',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026, 7),
          ),
        ];

        await syncer.pull(null);

        final row = await local.getByClientUuid('cu-1');
        expect(row!.name, 'Server name');
      },
    );

    test('LWW: a pending local edit NEWER than the server row is kept', () async {
      await local.upsert(
        _land(clientUuid: 'cu-1', id: 'server-1', name: 'Local edit'),
        pending: false,
      );
      await local.upsert(
        _land(
          clientUuid: 'cu-1',
          id: 'server-1',
          name: 'Local edit',
          updatedAt: DateTime.utc(2026, 8),
        ),
        pending: true,
      );
      remote.onGetLands = (since) => [
        _land(
          clientUuid: 'cu-1',
          id: 'server-1',
          name: 'Stale server value',
          updatedAt: DateTime.utc(2026, 6),
        ),
      ];

      await syncer.pull(null);

      final row = await local.getByClientUuid('cu-1');
      expect(row!.name, 'Local edit');
      expect(row.pending, isTrue);
    });

    test(
      'LWW: a NEWER server row overwrites a pending local edit',
      () async {
        await local.upsert(
          _land(
            clientUuid: 'cu-1',
            id: 'server-1',
            name: 'Local edit',
            updatedAt: DateTime.utc(2026, 6),
          ),
          pending: true,
        );
        remote.onGetLands = (since) => [
          _land(
            clientUuid: 'cu-1',
            id: 'server-1',
            name: 'Newer server value',
            updatedAt: DateTime.utc(2026, 8),
          ),
        ];

        await syncer.pull(null);

        final row = await local.getByClientUuid('cu-1');
        expect(row!.name, 'Newer server value');
        expect(row.pending, isFalse);
      },
    );

    test('delete-wins: does not resurrect a pending local delete', () async {
      await local.upsert(_land(clientUuid: 'cu-1', id: 'server-1'), pending: false);
      await local.markDeleted('cu-1');
      remote.onGetLands = (since) => [
        _land(
          clientUuid: 'cu-1',
          id: 'server-1',
          updatedAt: DateTime.utc(2026, 9),
        ),
      ];

      await syncer.pull(null);

      final row = await local.getByClientUuid('cu-1');
      expect(row, isNotNull);
      expect(row!.deletedLocally, isTrue);
      expect(row.pending, isTrue);
    });

    test('a clean (not pending) local row is overwritten outright', () async {
      await local.upsert(
        _land(
          clientUuid: 'cu-1',
          id: 'server-1',
          name: 'Old',
          updatedAt: DateTime.utc(2026, 10),
        ),
        pending: false,
      );
      remote.onGetLands = (since) => [
        _land(
          clientUuid: 'cu-1',
          id: 'server-1',
          name: 'New',
          updatedAt: DateTime.utc(2026),
        ),
      ];

      await syncer.pull(null);

      final row = await local.getByClientUuid('cu-1');
      expect(row!.name, 'New');
    });

    test('a NetworkException from getLands propagates (not swallowed)', () async {
      remote.throwOnGetLands = NetworkException();

      await expectLater(syncer.pull(null), throwsA(isA<NetworkException>()));
    });

    test('a ServerException from getLands propagates (not swallowed)', () async {
      remote.throwOnGetLands = const ServerException('boom');

      await expectLater(syncer.pull(null), throwsA(isA<ServerException>()));
    });
  });
}
