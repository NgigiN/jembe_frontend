// Golden end-to-end test for the `cost_category` offline read-through cache
// (Task 9a — see
// `.superpowers/sdd/2026-09-05-offline-first-p3-frontend-entity-rollout/task-9a-brief.md`).
//
// Mirrors `test/core/sync/revenue_offline_e2e_test.dart`'s shape (real
// `AppDatabase.forTesting`, real `OutboxDao`/`CostCategoryLocalDataSource`, a
// real `CostCategorySyncer` and `SyncEngine`, driven through a real
// `CostCategoryRepositoryImpl`) but proves the BESPOKE contract instead of
// `BaseEntitySyncer`'s LWW: this entity's create returns only a bool (never
// a server id), and its pull is always a FULL, unfiltered re-fetch — never a
// delta — that replaces every non-pending local row.
import 'package:dartz/dartz.dart';
import 'package:drift/native.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/offline/offline_config.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_local_data_source.dart';
import 'package:farm_tracker/features/farm/data/datasources/cost_category_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/cost_category_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/cost_category_repository_impl.dart';
import 'package:farm_tracker/features/farm/data/sync/cost_category_syncer.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake "server" for the `cost_category` entity.
///
/// Mirrors the real P1 semantics this outlier targets: `addCostCategory`
/// mints a server id and returns only a bool (never the created row);
/// `getCostCategories()` — called by the sync pull UNFILTERED, never with
/// `type`/`category` — returns every row currently held.
class _FakeCostCategoryRemoteDataSource implements CostCategoryRemoteDataSource {
  final Map<String, CostCategoryModel> _byServerId = <String, CostCategoryModel>{};
  int _nextId = 1;

  /// Every `client_uuid` [addCostCategory] was ever called with, in order.
  final List<String?> addClientUuids = <String?>[];

  /// Every `(type, category)` [getCostCategories] was ever called with, in
  /// order — the sync pull must always call this UNFILTERED (`null, null`).
  final List<(String?, String?)> getCostCategoriesCalls = <(String?, String?)>[];

  List<CostCategoryModel> get allRows => List.unmodifiable(_byServerId.values);

  @override
  Future<bool> addCostCategory({
    required String name,
    required String type,
    required String category,
    String? clientUuid,
  }) async {
    addClientUuids.add(clientUuid);
    final serverId = '${_nextId++}';
    _byServerId[serverId] = CostCategoryModel(
      id: serverId,
      clientUuid: '', // the server never echoes one back.
      name: name,
      type: type,
      category: category,
      isDefault: false,
    );
    return true;
  }

  @override
  Future<void> deleteCostCategory(String id) async {
    _byServerId.remove(id);
  }

  @override
  Future<List<CostCategoryModel>> getCostCategories({
    String? type,
    String? category,
  }) async {
    getCostCategoriesCalls.add((type, category));
    return _byServerId.values.toList();
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
    local = CostCategoryLocalDataSource(db);
    outbox = OutboxDao(db);
    cursors = SyncCursorDao(db);
    remote = _FakeCostCategoryRemoteDataSource();
    connectivity = _FakeConnectivityService();
    final syncer = CostCategorySyncer(remote: remote, local: local);
    engine = SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
    );
    repo = CostCategoryRepositoryImpl(
      remoteDataSource: remote,
      local: local,
      outbox: outbox,
      sync: engine,
    );
  }

  final AppDatabase db;
  late final CostCategoryLocalDataSource local;
  late final OutboxDao outbox;
  late final SyncCursorDao cursors;
  late final _FakeCostCategoryRemoteDataSource remote;
  late final _FakeConnectivityService connectivity;
  late final SyncEngine engine;
  late final CostCategoryRepositoryImpl repo;

  Future<void> dispose() async {
    engine.dispose();
    await db.close();
  }
}

/// Unwraps a repository `Either`, failing the test with the `Left` if it
/// isn't a `Right`.
T _unwrap<T>(Either<Failure, T> result) {
  return result.fold((failure) => fail('expected Right, got $failure'), (
    value,
  ) => value);
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
    'offline add -> reconnect -> pull full re-fetch converges: the fake '
    'server gets the create, the outbox drains, and the local mirror ends '
    'up keyed by the server-assigned "srv:" + id (never a real serverId '
    'reconciled through the create response, since addCostCategory returns '
    'only a bool)',
    () async {
      h.connectivity.online = false;

      final added = _unwrap(
        await h.repo.addCostCategory(
          name: 'Seeds',
          type: 'plant',
          category: 'input',
        ),
      );
      expect(added, isTrue);

      // --- Staged locally while offline; nothing has reached the server. ---
      expect(h.remote.addClientUuids, isEmpty);
      final pendingRows = await h.outbox.peekAll();
      expect(pendingRows, hasLength(1));
      expect(pendingRows.single.op, 'create');
      expect(pendingRows.single.entity, 'cost_category');
      final localClientUuid = pendingRows.single.clientUuid;

      final staged = await h.local.getByClientUuid(localClientUuid);
      expect(staged, isNotNull);
      expect(staged!.pending, isTrue);
      expect(staged.id, '', reason: 'no server id minted yet');

      // --- Reconnect: push the create, then the pull's full re-fetch runs
      // in the same pass. ---
      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(await h.outbox.peekAll(), isEmpty);
      expect(h.remote.addClientUuids, [localClientUuid]);
      expect(h.remote.allRows, hasLength(1));
      expect(
        h.remote.getCostCategoriesCalls,
        isNotEmpty,
        reason: 'the pull phase must have run',
      );
      for (final call in h.remote.getCostCategoriesCalls) {
        expect(
          call,
          (null, null),
          reason: 'the sync pull must call getCostCategories UNFILTERED',
        );
      }

      // The offline-minted clientUuid is superseded by the pull's
      // deterministic 'srv:'+serverId key — this is how a create's real
      // server id finally lands locally for this outlier (see
      // `CostCategorySyncer.pull`'s docs).
      final serverRow = h.remote.allRows.single;
      final reconciled = await h.local.getByServerId(serverRow.id);
      expect(reconciled, isNotNull);
      expect(reconciled!.clientUuid, 'srv:${serverRow.id}');
      expect(reconciled.name, 'Seeds');
      expect(reconciled.pending, isFalse);
      expect(
        await h.local.getByClientUuid(localClientUuid),
        isNull,
        reason:
            "the original offline clientUuid's row was replaced by the "
            'full re-fetch once it was no longer pending',
      );

      // --- getCostCategories (flag-on read-through) now sees exactly this
      // one category, filtered. ---
      final visible = _unwrap(
        await h.repo.getCostCategories(type: 'plant', category: 'input'),
      );
      expect(visible, hasLength(1));
      expect(visible.single.name, 'Seeds');

      // --- A second pull with no server-side change is idempotent. ---
      await h.engine.syncNow();
      final rowsAfterSecondSync = await h.db.select(h.db.costCategories).get();
      expect(rowsAfterSecondSync, hasLength(1));
      expect(rowsAfterSecondSync.single.clientUuid, 'srv:${serverRow.id}');

      // --- Deleting the now-synced category pushes a real server delete. ---
      await h.repo.deleteCostCategory('srv:${serverRow.id}');
      await h.engine.syncNow();

      expect(h.remote.allRows, isEmpty);
      expect(await h.local.getByServerId(serverRow.id), isNull);
      final visibleAfterDelete = _unwrap(await h.repo.getCostCategories());
      expect(visibleAfterDelete, isEmpty);
    },
  );

  test(
    'offline create+delete annihilation: the fake server never sees an '
    'addCostCategory for the row',
    () async {
      h.connectivity.online = false;

      final added = _unwrap(
        await h.repo.addCostCategory(
          name: 'Ghost',
          type: 'plant',
          category: 'input',
        ),
      );
      expect(added, isTrue);

      final pendingRows = await h.outbox.peekAll();
      final ghostClientUuid = pendingRows.single.clientUuid;
      await h.repo.deleteCostCategory(ghostClientUuid);

      expect(await h.outbox.peekAll(), isEmpty);

      h.connectivity.online = true;
      await h.engine.syncNow();

      expect(h.remote.addClientUuids, isEmpty);
      expect(h.remote.allRows, isEmpty);
      // The annihilated row's local tombstone can outlive the annihilation
      // (no outbox `delete` entry is ever left to trigger a `hardDelete` —
      // same as `land`/`revenue`'s equivalent case), but it must never be
      // visible through the read-through cache.
      final visible = await h.local.getCostCategories();
      expect(visible.map((c) => c.clientUuid), isNot(contains(ghostClientUuid)));
    },
  );
}
