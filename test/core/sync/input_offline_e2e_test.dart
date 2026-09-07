// Golden end-to-end test for the offline-first input pipeline (Task 7b —
// see `.superpowers/sdd/2026-09-05-offline-first-p3-frontend-entity-rollout/task-7-brief.md`).
//
// Mirrors `test/core/sync/harvest_offline_e2e_test.dart`: wires the REAL
// collaborators together — a real `AppDatabase.forTesting` (in-memory
// sqlite via drift), real `OutboxDao`/`SyncCursorDao`/`InputLocalDataSource`,
// a real `InputSyncer` and a real `SyncEngine`, driven through a real
// `InputRepositoryImpl` — and proves the whole loop converges against a
// fake in-memory "server". Only the network boundary
// (`InputRemoteDataSource`, `DeletionsApplier`) and the OS connectivity
// signal are faked.
//
// Unlike harvest's `seasonId` filter, input's `sourceType` scoped-watch
// scenario below has NO P4/clientUuid concern: `sourceType` is a stable
// string discriminator ('plant'/'animal'/…), not a parent id — see
// `InputLocalDataSource.watchInputs`'s doc comment. The `sourceId`/`animalId`
// FK (a separate, genuine P4 concern) is sidestepped here by always
// targeting an already-synced parent, per `InputModel`'s `// TODO(P4)` note.
import 'package:dartz/dartz.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/input_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/input_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/input_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/input_syncer.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `input` entity.
///
/// Mirrors the P1 REST semantics this pilot targets: `addInput` mints a
/// server id and is idempotent on `client_uuid`; `getInputs(updatedSince:)`
/// returns rows whose `updatedAt >= updatedSince` (or every row when null) —
/// the sync pull always calls it this way, never with `sourceType`.
/// [seedServerRow] lets a test inject a server-side row directly — e.g. to
/// simulate a change made from another device.
class _FakeInputRemoteDataSource implements InputRemoteDataSource {
  final Map<String, InputModel> _byServerId = <String, InputModel>{};
  final Map<String, String> _serverIdByClientUuid = <String, String>{};
  int _nextId = 1;

  /// Every `client_uuid` [addInput] was ever called with, in call order.
  final List<String> addInputClientUuids = <String>[];

  /// Every row currently held by the fake server.
  List<InputModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<InputModel> addInput(InputModel input) async {
    addInputClientUuids.add(input.clientUuid);
    final existingServerId = _serverIdByClientUuid[input.clientUuid];
    if (existingServerId != null) {
      // Idempotent replay: same clientUuid comes back as the SAME row.
      return _byServerId[existingServerId]!;
    }

    final serverId = '${_nextId++}';
    final stored = InputModel(
      id: serverId,
      clientUuid: input.clientUuid,
      sourceType: input.sourceType,
      sourceId: input.sourceId,
      animalId: input.animalId,
      type: input.type,
      quantity: input.quantity,
      cost: input.cost,
      date: input.date,
      notes: input.notes,
      createdAt: input.createdAt,
      updatedAt: input.updatedAt,
    );
    _byServerId[serverId] = stored;
    _serverIdByClientUuid[input.clientUuid] = serverId;
    return stored;
  }

  @override
  Future<InputModel> updateInput(InputModel input) async {
    final existing = _byServerId[input.id];
    final stored = InputModel(
      id: input.id,
      clientUuid: existing?.clientUuid ?? input.clientUuid,
      sourceType: input.sourceType,
      sourceId: input.sourceId,
      animalId: input.animalId,
      type: input.type,
      quantity: input.quantity,
      cost: input.cost,
      date: input.date,
      notes: input.notes,
      createdAt: existing?.createdAt ?? input.createdAt,
      updatedAt: input.updatedAt,
    );
    _byServerId[input.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteInput(String id) async {
    final removed = _byServerId.remove(id);
    if (removed != null) {
      _serverIdByClientUuid.remove(removed.clientUuid);
    }
  }

  @override
  Future<List<InputModel>> getInputs({
    String? sourceType,
    DateTime? updatedSince,
    int? limit,
    int? cursor,
  }) async {
    Iterable<InputModel> rows = _byServerId.values;
    if (sourceType != null && sourceType.isNotEmpty) {
      rows = rows.where((row) => row.sourceType == sourceType);
    }
    if (updatedSince != null) {
      rows = rows.where((row) => !row.updatedAt.isBefore(updatedSince));
    }
    return rows.toList();
  }

  /// Test-only: injects/replaces a server-side row directly, bypassing
  /// [addInput] — simulates an inbound change from another device.
  void seedServerRow(InputModel row) {
    _byServerId[row.id] = row;
    if (row.clientUuid.isNotEmpty) {
      _serverIdByClientUuid[row.clientUuid] = row.id;
    }
  }
}

/// Fake `/sync/deletions` applier: a test [addTombstone]s a `clientUuid` and
/// the next [applyDeletions] hard-deletes that row locally.
class _FakeDeletionsApplier implements DeletionsApplier {
  _FakeDeletionsApplier(this._local);

  final InputLocalDataSource _local;
  final List<String> _pendingTombstones = <String>[];
  int applyCount = 0;

  void addTombstone(String clientUuid) => _pendingTombstones.add(clientUuid);

  @override
  Future<void> applyDeletions(DateTime? since) async {
    applyCount++;
    for (final clientUuid in _pendingTombstones) {
      await _local.hardDelete(clientUuid);
    }
  }
}

/// Controllable fake of [ConnectivityService] — a plain online/offline
/// switch a test flips directly, no platform channel involved.
class _FakeConnectivityService implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => const Stream<bool>.empty();
}

/// Wires every REAL offline-first collaborator around one in-memory
/// [AppDatabase], plus the fakes at the network boundary.
class _Harness {
  _Harness() : db = AppDatabase.forTesting(NativeDatabase.memory()) {
    local = InputLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeInputRemoteDataSource();
    deletions = _FakeDeletionsApplier(local);
    connectivity = _FakeConnectivityService();
    final syncer = InputSyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
    );
    repo = InputRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final InputLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeInputRemoteDataSource remote;
  late final _FakeDeletionsApplier deletions;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final InputRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Builds a domain [Input] targeting an already-synced parent season
/// (server id `'801'`) to pass into the repository.
Input _domainInput({
  String id = '',
  String sourceType = 'plant',
  double cost = 100,
  double? quantity = 5,
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? notes,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return Input(
    id: id,
    sourceType: sourceType,
    sourceId: '801',
    type: 'Fertilizer',
    quantity: quantity,
    cost: cost,
    date: date ?? at,
    notes: notes,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Builds an [InputModel] for seeding the local mirror or the fake server
/// directly (bypassing the repository).
InputModel _input({
  required String clientUuid,
  String id = '',
  String sourceType = 'plant',
  String sourceId = '801',
  double cost = 100,
  DateTime? date,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final at = createdAt ?? DateTime.utc(2026);
  return InputModel(
    id: id,
    clientUuid: clientUuid,
    sourceType: sourceType,
    sourceId: sourceId,
    type: 'Fertilizer',
    cost: cost,
    date: date ?? at,
    createdAt: at,
    updatedAt: updatedAt ?? at,
  );
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
Input _unwrap(Either<Failure, Input> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    input,
  ) => input);
}

void main() {
  late _Harness h;

  setUp(() {
    h = _Harness();
    OfflineConfig.enabled = true;
  });

  tearDown(() async {
    OfflineConfig.enabled = false;
    await h.dispose();
  });

  test(
    'offline burst (2 creates, 1 edit) coalesces in the outbox, then '
    'reconnect + syncNow converges: server has both inputs with the edit '
    'applied, local serverIds are populated, outbox is empty',
    () async {
      h.connectivity.online = false;

      final input1 = _unwrap(
        await h.repo.addInput(_domainInput(cost: 100)),
      );
      final input2 = _unwrap(
        await h.repo.addInput(_domainInput(cost: 200)),
      );

      await h.repo.updateInput(
        Input(
          id: input2.id,
          sourceType: input2.sourceType,
          sourceId: input2.sourceId,
          type: input2.type,
          quantity: input2.quantity,
          cost: 250,
          date: input2.date,
          notes: input2.notes,
          createdAt: input2.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      // --- Outbox coalesced BEFORE any sync attempt ---
      final pendingRows = await h.outbox.peekAll();
      expect(
        pendingRows.map((r) => r.clientUuid).toSet(),
        {input1.id, input2.id},
      );
      expect(pendingRows.every((r) => r.op == 'create'), isTrue);
      expect(pendingRows, hasLength(2));

      // --- Reconnect and converge ---
      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(await h.outbox.peekAll(), isEmpty);
      expect(h.remote.allRows, hasLength(2));

      final serverCosts = {
        for (final r in h.remote.allRows) r.clientUuid: r.cost,
      };
      expect(serverCosts[input1.id], 100);
      expect(serverCosts[input2.id], 250);

      final local1 = await h.local.getByClientUuid(input1.id);
      final local2 = await h.local.getByClientUuid(input2.id);
      expect(local1, isNotNull);
      expect(local2, isNotNull);
      expect(local1!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2!.id, isNotEmpty, reason: 'serverId reconciled');
      expect(local2.cost, 250);

      // The already-synced parent (`sourceId`) is pushed through untouched
      // (P3 scope — no clientUuid->serverId FK translation attempted).
      final pushed = h.remote.allRows.firstWhere(
        (r) => r.clientUuid == input1.id,
      );
      expect(pushed.sourceId, '801');
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addInput for the row',
    () async {
      h.connectivity.online = false;

      final ghost = _unwrap(
        await h.repo.addInput(_domainInput(cost: 999)),
      );
      await h.repo.deleteInput(ghost.id);

      final rows = await h.outbox.peekAll();
      expect(rows.where((r) => r.clientUuid == ghost.id), isEmpty);
      expect(rows, isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addInputClientUuids, isNot(contains(ghost.id)));
      expect(h.remote.allRows, isEmpty);

      final visible = await h.local.watchInputs().first;
      expect(visible, isEmpty);
    },
  );

  test(
    'inbound update: a newer server row overwrites the local mirror on '
    'pull',
    () async {
      await h.local.upsert(
        _input(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          cost: 50,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );

      h.remote.seedServerRow(
        _input(
          clientUuid: 'cu-inbound-update',
          id: 'srv-1',
          cost: 550,
          updatedAt: DateTime.utc(2026, 6),
        ),
      );

      await h.engine.syncNow();

      final row = await h.local.getByClientUuid('cu-inbound-update');
      expect(row, isNotNull);
      expect(row!.cost, 550);
      expect(row.pending, isFalse);
    },
  );

  test(
    'inbound tombstone: a server-reported deletion hard-deletes the local '
    'row, which then disappears from watchInputs',
    () async {
      await h.local.upsert(
        _input(clientUuid: 'cu-tombstoned', id: 'srv-2'),
        pending: false,
      );
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNotNull);

      h.deletions.addTombstone('cu-tombstoned');

      await h.engine.syncNow();

      expect(h.deletions.applyCount, 1);
      expect(await h.local.getByClientUuid('cu-tombstoned'), isNull);

      final visible = await h.local.watchInputs().first;
      expect(
        visible.map((m) => m.clientUuid),
        isNot(contains('cu-tombstoned')),
      );
    },
  );

  test(
    'LWW: a newer local pending edit beats a stale server row, and a newer '
    'server row beats a stale local pending edit',
    () async {
      // --- (a) local pending edit is NEWER than the server's row: local
      // wins. ---
      await h.local.upsert(
        _input(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          cost: 1,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _input(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          cost: 2,
          updatedAt: DateTime.utc(2026, 3),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _input(
          clientUuid: 'cu-lww-local-wins',
          id: 'srv-a',
          cost: 3,
          updatedAt: DateTime.utc(2026, 2),
        ),
      );

      await h.engine.syncNow();

      final localWinsRow = await h.local.getByClientUuid(
        'cu-lww-local-wins',
      );
      expect(localWinsRow, isNotNull);
      expect(localWinsRow!.cost, 2);
      expect(localWinsRow.pending, isTrue);

      // --- (b) server row is NEWER than the local pending edit: server
      // wins. ---
      await h.local.upsert(
        _input(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          cost: 1,
          updatedAt: DateTime.utc(2026),
        ),
        pending: false,
      );
      await h.local.upsert(
        _input(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          cost: 2,
          updatedAt: DateTime.utc(2026, 2),
        ),
        pending: true,
      );
      h.remote.seedServerRow(
        _input(
          clientUuid: 'cu-lww-server-wins',
          id: 'srv-b',
          cost: 4,
          updatedAt: DateTime.utc(2026, 4),
        ),
      );

      await h.engine.syncNow();

      final serverWinsRow = await h.local.getByClientUuid(
        'cu-lww-server-wins',
      );
      expect(serverWinsRow, isNotNull);
      expect(serverWinsRow!.cost, 4);
      expect(serverWinsRow.pending, isFalse);
    },
  );

  test(
    'watchInputs(sourceType:) stays scoped to that source type through an '
    'offline create + reconnect sync — sourceType is a stable discriminator, '
    'not a parent id, so this filter is unaffected by the sourceId/animalId '
    'P4 FK concern',
    () async {
      h.connectivity.online = false;

      await h.repo.addInput(_domainInput(sourceType: 'plant', cost: 7));
      await h.repo.addInput(_domainInput(sourceType: 'animal', cost: 999));

      final scoped = await h.local.watchInputs(sourceType: 'plant').first;
      expect(scoped, hasLength(1));
      expect(scoped.single.cost, 7);

      h.connectivity.online = true;
      await h.engine.syncNow();

      final scopedAfterSync = await h.local
          .watchInputs(sourceType: 'plant')
          .first;
      expect(scopedAfterSync, hasLength(1));
      expect(scopedAfterSync.single.cost, 7);
    },
  );
}
