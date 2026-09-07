import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_engine.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

OutboxRow _row(
  int seq, {
  String entity = 'land',
  String op = 'create',
  String clientUuid = 'a',
  String state = 'pending',
  int attempts = 0,
}) {
  return OutboxRow(
    seq: seq,
    entity: entity,
    op: op,
    clientUuid: clientUuid,
    payload: '{}',
    attempts: attempts,
    state: state,
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  // The fake DAOs each build a throwaway in-memory AppDatabase they never
  // touch (they override every method the engine calls); silence drift's
  // "multiple databases" heuristic warning for these test-only fakes.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _FakeConnectivity connectivity;
  late _FakeOutbox outbox;
  late _FakeCursors cursors;
  late _FakeDeletions deletions;
  late _FakeSyncer syncer;
  late List<String> events;
  late SyncEngine engine;

  SyncEngine build({
    List<OutboxRow> rows = const [],
    Future<bool> Function()? isAuthenticated,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    events = <String>[];
    connectivity = _FakeConnectivity();
    outbox = _FakeOutbox(List.of(rows));
    cursors = _FakeCursors();
    deletions = _FakeDeletions(events);
    syncer = _FakeSyncer('land', events);
    return SyncEngine(
      outbox: outbox,
      syncers: [syncer],
      cursors: cursors,
      connectivity: connectivity,
      deletions: deletions,
      isAuthenticated: isAuthenticated,
      onError: onError,
    );
  }

  setUp(() {
    engine = build();
  });

  tearDown(() {
    engine.dispose();
    connectivity.dispose();
  });

  test('offline: syncNow calls no push or pull (no-op)', () async {
    engine = build(rows: [_row(1)]);
    connectivity.online = false;

    await engine.syncNow();

    expect(syncer.pushCount, 0);
    expect(syncer.pullCount, 0);
    expect(outbox.acked, isEmpty);
    expect(engine.status.phase, SyncPhase.idle);
    expect(engine.status.pendingCount, 1);
  });

  test('unauthenticated: syncNow calls no push or pull (no-op) even when '
      'online', () async {
    engine = build(rows: [_row(1)], isAuthenticated: () async => false);

    await engine.syncNow();

    expect(syncer.pushCount, 0);
    expect(syncer.pullCount, 0);
    expect(outbox.acked, isEmpty);
    expect(engine.status.phase, SyncPhase.idle);
    expect(engine.status.pendingCount, 1);
  });

  test('authenticated + online: the pass runs as before', () async {
    engine = build(rows: [_row(1)], isAuthenticated: () async => true);

    await engine.syncNow();

    expect(syncer.pushCount, 1);
    expect(syncer.pullCount, 1);
    expect(outbox.acked, [1]);
    expect(engine.status.phase, SyncPhase.idle);
  });

  test('push runs before pull, deletions runs last', () async {
    engine = build(rows: [_row(1)]);

    await engine.syncNow();

    expect(events, ['push:land', 'pull:land', 'deletions']);
  });

  test('successful push acks the entry and ends idle', () async {
    engine = build(rows: [_row(7)]);

    await engine.syncNow();

    expect(syncer.pushCount, 1);
    expect(outbox.acked, [7]);
    expect(engine.status.phase, SyncPhase.idle);
    expect(engine.status.lastSyncedAt, isNotNull);
    expect(engine.status.pendingCount, 0);
  });

  test('single-flight: overlapping syncNow pushes once, then coalesces one '
      'more pass, never concurrently', () async {
    engine = build(rows: [_row(1)]);
    final gate = Completer<void>();
    syncer.pushGate = gate;

    final f1 = engine.syncNow();
    final f2 = engine.syncNow();
    // Both calls resolve to the same in-flight future.
    expect(identical(f1, f2), isTrue);

    gate.complete();
    await Future.wait([f1, f2]);

    // Entry pushed exactly once (pass 2 sees an empty outbox), never overlapping.
    expect(syncer.pushCount, 1);
    expect(syncer.maxConcurrentPush, 1);
    // Two passes ran: pull invoked once per pass.
    expect(syncer.pullCount, 2);
  });

  test('permanent (ServerException) push: entry marked failed, engine '
      'continues to the next entry', () async {
    engine = build(
      rows: [
        _row(1),
        _row(2, clientUuid: 'b'),
      ],
    );
    syncer.onPush = (row) => row.seq == 1 ? const ServerException('4xx') : null;

    await engine.syncNow();

    expect(syncer.pushCount, 2); // both attempted
    expect(outbox.failed, [1]); // parked
    expect(outbox.acked, [2]); // second succeeded
    // Permanent failures don't flip the pass to error; pull still runs.
    expect(engine.status.phase, SyncPhase.idle);
    expect(syncer.pullCount, 1);
  });

  test('parks (keeps pending, no backoff) when a syncer reports a missing '
      'parent', () async {
    engine = build(rows: [_row(1)]);
    syncer.onPush = (row) => SyncDependencyException();

    await engine.syncNow();

    // Not acked (not synced) and not marked failed (not a real failure) —
    // just left pending with the attempt count bumped.
    expect(syncer.pushCount, 1);
    expect(outbox.acked, isEmpty);
    expect(outbox.failed, isEmpty);
    expect(outbox.bumped, [1]);
    expect(outbox.stateOf(1), 'pending');
    expect(outbox.attemptsOf(1), 1);
    // No backoff: the phase keeps draining and the pass ends idle, pull
    // still runs — unlike a transient NetworkException stop.
    expect(engine.status.phase, SyncPhase.idle);
    expect(engine.status.pendingCount, 1);
    expect(syncer.pullCount, 1);
  });

  test('bounded parking: once the max park attempts are reached, the entry '
      'is marked failed instead of parked again', () async {
    engine = build(rows: [_row(1, attempts: 9)]);
    syncer.onPush = (row) => SyncDependencyException();

    await engine.syncNow();

    expect(outbox.bumped, isEmpty);
    expect(outbox.failed, [1]);
    expect(engine.status.phase, SyncPhase.idle);
  });

  test(
    'entry whose entity has no registered syncer is skipped, not crashed',
    () async {
      engine = build(
        rows: [
          _row(1, entity: 'ghost'),
          _row(2),
        ],
      );

      await engine.syncNow();

      // ghost skipped, land pushed + acked.
      expect(outbox.acked, [2]);
      expect(engine.status.phase, SyncPhase.idle);
    },
  );

  test('pull advances the cursor and applyDeletions is called', () async {
    final newCursor = DateTime.utc(2026, 5, 5, 12);
    engine = build();
    syncer.pullResult = newCursor;

    await engine.syncNow();

    expect(syncer.pullCount, 1);
    expect(cursors.storage['land']!.isAtSameMomentAs(newCursor), isTrue);
    expect(deletions.applyCount, 1);
  });

  test('pull passes the stored cursor to the syncer as "since"', () async {
    final since = DateTime.utc(2026, 4);
    engine = build();
    cursors.storage['land'] = since;

    await engine.syncNow();

    expect(syncer.pullSinceArgs, hasLength(1));
    expect(syncer.pullSinceArgs.single!.isAtSameMomentAs(since), isTrue);
  });

  group('deletions cursor excludes cursorless syncers', () {
    // A cursorless syncer (`hasCursor = false`, e.g. `CostCategorySyncer` —
    // no timestamps, `pull` always returns `null`) has a PERMANENTLY null
    // entry in `preCursors`. Before this fix, `_oldestCursor` would treat
    // that the same as a genuinely-unsynced entity and force
    // `applyDeletions(null)` (a full replay) on every single pass, forever.
    late _FakeSyncer landSyncer;
    late _FakeSyncer costCategorySyncer;
    late _FakeCursors localCursors;
    late _FakeDeletions localDeletions;
    late _FakeConnectivity localConnectivity;
    late SyncEngine localEngine;

    void buildTwoSyncerEngine() {
      landSyncer = _FakeSyncer('land', events);
      costCategorySyncer = _FakeSyncer('cost_category', events)
        ..hasCursor = false;
      localCursors = _FakeCursors();
      localDeletions = _FakeDeletions(events);
      localConnectivity = _FakeConnectivity();
      localEngine = SyncEngine(
        outbox: _FakeOutbox(const []),
        syncers: [landSyncer, costCategorySyncer],
        cursors: localCursors,
        connectivity: localConnectivity,
        deletions: localDeletions,
      );
    }

    tearDown(() {
      localEngine.dispose();
      localConnectivity.dispose();
    });

    test(
      'a cursor-bearing entity with an already-set cursor calls '
      'applyDeletions with THAT cursor, not null — the cursorless '
      "syncer's perpetual-null cursor no longer forces a full replay",
      () async {
        buildTwoSyncerEngine();
        final since = DateTime.utc(2026, 4);
        localCursors.storage['land'] = since;
        // cost_category never gets an entry in `storage` — its cursor is
        // permanently null; it must not drag the computation down to null.

        await localEngine.syncNow();

        expect(localDeletions.sinceArgs, hasLength(1));
        expect(localDeletions.sinceArgs.single, isNotNull);
        expect(
          localDeletions.sinceArgs.single!.isAtSameMomentAs(since),
          isTrue,
        );
      },
    );

    test(
      'a genuinely-unsynced cursor-bearing entity (null cursor) still '
      'forces applyDeletions(null), even alongside a cursorless syncer',
      () async {
        buildTwoSyncerEngine();
        // Neither `land` nor `cost_category` has a stored cursor. `land` IS
        // cursor-bearing, so its null cursor must still force a full replay.

        await localEngine.syncNow();

        expect(localDeletions.sinceArgs, [null]);
      },
    );
  });

  group('empty-pull cursor advance', () {
    // Regression coverage: before this fix, a cursor-bearing syncer whose
    // pull SUCCEEDED but returned null (no rows changed) never had its
    // cursor set at all. Its cursor stayed permanently null, so
    // `_oldestCursor` kept returning null forever, forcing an unbounded full
    // `/sync/deletions` replay on every single pass. The fix advances the
    // cursor to (pass-start − 2 minutes) instead.
    late _FakeSyncer landSyncer;
    late _FakeCursors localCursors;
    late _FakeDeletions localDeletions;
    late _FakeConnectivity localConnectivity;
    late SyncEngine localEngine;
    late DateTime fakeNow;

    void buildEngine() {
      landSyncer = _FakeSyncer('land', events);
      localCursors = _FakeCursors();
      localDeletions = _FakeDeletions(events);
      localConnectivity = _FakeConnectivity();
      localEngine = SyncEngine(
        outbox: _FakeOutbox(const []),
        syncers: [landSyncer],
        cursors: localCursors,
        connectivity: localConnectivity,
        deletions: localDeletions,
        now: () => fakeNow,
      );
    }

    tearDown(() {
      localEngine.dispose();
      localConnectivity.dispose();
    });

    test(
      'a successful empty pull (null result) advances the cursor to '
      'pass-start minus a 2-minute buffer, instead of leaving it null',
      () async {
        fakeNow = DateTime.utc(2026, 5, 5, 12);
        buildEngine();
        // landSyncer.pullResult defaults to null: a successful, empty pull.

        await localEngine.syncNow();

        expect(localCursors.storage['land'], isNotNull);
        expect(
          localCursors.storage['land']!.isAtSameMomentAs(
            fakeNow.subtract(const Duration(minutes: 2)),
          ),
          isTrue,
        );
      },
    );

    test(
      'once every cursor-bearing entity has a cursor (even buffer-advanced), '
      'a later pass calls applyDeletions with a non-null since — no more '
      'forced full replay',
      () async {
        fakeNow = DateTime.utc(2026, 5, 5, 12);
        buildEngine();

        await localEngine.syncNow(); // pass 1: empty pull, cursor advances.
        fakeNow = fakeNow.add(const Duration(minutes: 10));
        await localEngine.syncNow(); // pass 2: preCursors now sees it.

        expect(localDeletions.sinceArgs, hasLength(2));
        // pass 1 still forces a full replay (preCursors snapshotted BEFORE
        // pass 1's pull loop advanced the cursor).
        expect(localDeletions.sinceArgs[0], isNull);
        // pass 2 sees the cursor the fix set during pass 1.
        expect(localDeletions.sinceArgs[1], isNotNull);
      },
    );
  });

  test('transient (NetworkException) push: entry not acked, status error, '
      'backoff retry fires and succeeds once the syncer recovers', () {
    fakeAsync((async) {
      engine = build(rows: [_row(1)]);
      var throwNetwork = true;
      syncer.onPush = (row) => throwNetwork ? NetworkException() : null;

      unawaited(engine.syncNow());
      async.flushMicrotasks();

      // First pass: push attempted, threw, entry left queued, error emitted.
      expect(syncer.pushCount, 1);
      expect(outbox.acked, isEmpty);
      expect(engine.status.phase, SyncPhase.error);
      // Pull is skipped when the push phase hits a transient stop.
      expect(syncer.pullCount, 0);

      // Recover, then let the backoff timer fire (cap is 60s).
      throwNetwork = false;
      async.elapse(const Duration(seconds: 61));

      expect(syncer.pushCount, 2); // retried
      expect(outbox.acked, [1]); // now acked
      expect(engine.status.phase, SyncPhase.idle);

      engine.dispose();
    });
  });

  test('transient stop halts the push phase, leaving later entries queued', () {
    fakeAsync((async) {
      engine = build(
        rows: [
          _row(1),
          _row(2, clientUuid: 'b'),
        ],
      );
      syncer.onPush = (row) => row.seq == 1 ? NetworkException() : null;

      unawaited(engine.syncNow());
      async.flushMicrotasks();

      // Stopped at seq 1; seq 2 never attempted this pass.
      expect(syncer.pushCount, 1);
      expect(outbox.acked, isEmpty);
      expect(engine.status.phase, SyncPhase.error);

      engine.dispose();
    });
  });

  test('transient (NetworkException) pull: status error + backoff retry that '
      'fires and succeeds once pull recovers; state stays consistent', () {
    fakeAsync((async) {
      engine = build(rows: [_row(1)]);
      final recovered = DateTime.utc(2026, 7);
      syncer.pullThrows = NetworkException();

      unawaited(engine.syncNow());
      async.flushMicrotasks();

      // Push succeeded and acked BEFORE pull failed; pull left the cursor be.
      expect(outbox.acked, [1]);
      expect(engine.status.phase, SyncPhase.error);
      expect(cursors.storage.containsKey('land'), isFalse);

      // Recover pull; let the backoff timer fire (cap 60s).
      syncer
        ..pullThrows = null
        ..pullResult = recovered;
      async.elapse(const Duration(seconds: 61));

      expect(engine.status.phase, SyncPhase.idle);
      expect(cursors.storage['land']!.isAtSameMomentAs(recovered), isTrue);

      engine.dispose();
    });
  });

  test(
    'generic pull error: status ends error, pass does not wedge, syncNow '
    'completes without an unhandled error, a later syncNow still runs',
    () async {
      engine = build(rows: [_row(1)]);
      syncer.pullThrows = Exception('boom');

      // Must complete normally — no unhandled async error escapes the pass.
      await engine.syncNow();

      expect(engine.status.phase, SyncPhase.error);
      expect(outbox.acked, [1]); // push still succeeded

      // No auto-retry for a non-transient fault, but a fresh trigger works.
      syncer.pullThrows = null;
      await engine.syncNow();

      expect(engine.status.phase, SyncPhase.idle);
    },
  );

  test('generic applyDeletions error: pass ends error without wedging; a '
      'later syncNow still reaches idle', () async {
    engine = build(rows: [_row(1)]);
    deletions.applyThrows = Exception('deletions down');

    await engine.syncNow();

    expect(engine.status.phase, SyncPhase.error);
    expect(outbox.acked, [1]); // push + pull ok; only deletions failed

    deletions.applyThrows = null;
    await engine.syncNow();

    expect(engine.status.phase, SyncPhase.idle);
  });

  test('generic (non-network) error: the injected onError hook is called '
      'with the error + stack trace, and status ends error', () async {
    final logged = <Object>[];
    final loggedStackTraces = <StackTrace>[];
    engine = build(
      rows: [_row(1)],
      onError: (error, stackTrace) {
        logged.add(error);
        loggedStackTraces.add(stackTrace);
      },
    );
    final thrown = Exception('boom');
    syncer.pullThrows = thrown;

    await engine.syncNow();

    expect(logged, [thrown]);
    expect(loggedStackTraces, hasLength(1));
    expect(engine.status.phase, SyncPhase.error);
  });

  test('transient (NetworkException) error: the injected onError hook is '
      'NOT called (backoff retry is the signal for an expected/offline '
      'failure, not a log line)', () {
    fakeAsync((async) {
      var calls = 0;
      engine = build(rows: [_row(1)], onError: (error, stackTrace) => calls++);
      syncer.onPush = (row) => NetworkException();

      unawaited(engine.syncNow());
      async.flushMicrotasks();

      expect(engine.status.phase, SyncPhase.error);
      expect(calls, 0);

      engine.dispose();
    });
  });

  test('no onError hook supplied: a generic error still ends status error '
      'without throwing (default no-op)', () async {
    engine = build(rows: [_row(1)]);
    syncer.pullThrows = Exception('boom');

    await engine.syncNow();

    expect(engine.status.phase, SyncPhase.error);
  });

  group('unauthorized (401): transient-auth stop, not a fault', () {
    test('push 401: entry left pending (not acked, not failed), status error, '
        'pull skipped', () {
      fakeAsync((async) {
        engine = build(
          rows: [
            _row(1),
            _row(2, clientUuid: 'b'),
          ],
        );
        syncer.onPush = (row) => UnauthorizedException();

        unawaited(engine.syncNow());
        async.flushMicrotasks();

        expect(syncer.pushCount, 1); // stopped at the first row
        expect(outbox.acked, isEmpty);
        expect(outbox.failed, isEmpty); // NOT parked — the row isn't at fault
        expect(outbox.stateOf(1), 'pending');
        expect(engine.status.phase, SyncPhase.error);
        expect(syncer.pullCount, 0); // pull skipped after the transient stop

        engine.dispose();
      });
    });

    test('pull 401: status error, push ack preserved', () {
      fakeAsync((async) {
        engine = build(rows: [_row(1)]);
        syncer.pullThrows = UnauthorizedException();

        unawaited(engine.syncNow());
        async.flushMicrotasks();

        expect(outbox.acked, [1]); // push succeeded before the pull 401
        expect(engine.status.phase, SyncPhase.error);

        engine.dispose();
      });
    });

    test('401 is NOT routed through onError (expected auth condition, not a '
        'bug to log at error level)', () async {
      final logged = <Object>[];
      engine = build(
        rows: [_row(1)],
        onError: (error, stackTrace) => logged.add(error),
      );
      syncer.pullThrows = UnauthorizedException();

      await engine.syncNow();

      expect(engine.status.phase, SyncPhase.error);
      expect(logged, isEmpty); // unlike a generic (non-auth) error
    });
  });

  test('start(): regaining connectivity triggers a sync', () async {
    engine = build(rows: [_row(1)])..start();

    connectivity.emit(true);
    // Let the stream event + the sync pass drain.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(syncer.pushCount, greaterThanOrEqualTo(1));
    expect(outbox.acked, [1]);
  });

  test(
    'statusStream emits syncing then idle across a successful pass',
    () async {
      engine = build(rows: [_row(1)]);
      final phases = <SyncPhase>[];
      final sub = engine.statusStream.listen((s) => phases.add(s.phase));

      await engine.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(phases.first, SyncPhase.syncing);
      expect(phases.last, SyncPhase.idle);
    },
  );
}

class _FakeConnectivity implements ConnectivityService {
  bool online = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  // ignore: avoid_positional_boolean_parameters
  void emit(bool value) => _controller.add(value);

  void dispose() => _controller.close();
}

class _FakeSyncer implements EntitySyncer {
  _FakeSyncer(this.entity, this._events);

  @override
  final String entity;
  final List<String> _events;

  /// Settable so a test can build a "cost_category-like" cursorless syncer
  /// (`hasCursor = false`) alongside a normal cursor-bearing one — defaults
  /// to `true` (every existing test's fake syncer is cursor-bearing, like
  /// `land`).
  @override
  bool hasCursor = true;

  int pushCount = 0;
  int pullCount = 0;
  int _inPush = 0;
  int maxConcurrentPush = 0;
  final List<DateTime?> pullSinceArgs = <DateTime?>[];

  /// Returns an exception to throw for the row, or null to succeed.
  Exception? Function(OutboxRow row)? onPush;

  /// New cursor returned by `pull`.
  DateTime? pullResult;

  /// When set, `pull` throws this (e.g. a NetworkException or a generic
  /// Exception). Clear it to simulate recovery.
  Object? pullThrows;

  /// When set, `push` awaits this before completing (to force overlap).
  Completer<void>? pushGate;

  @override
  Future<void> push(OutboxRow entry, FkResolver resolver) async {
    _inPush++;
    maxConcurrentPush = max(maxConcurrentPush, _inPush);
    pushCount++;
    _events.add('push:$entity');
    try {
      final gate = pushGate;
      if (gate != null) await gate.future;
      final ex = onPush?.call(entry);
      if (ex != null) throw ex;
    } finally {
      _inPush--;
    }
  }

  @override
  Future<DateTime?> pull(DateTime? since) async {
    pullCount++;
    pullSinceArgs.add(since);
    _events.add('pull:$entity');
    final error = pullThrows;
    // Rethrow whatever the test injected (Network/Server/generic).
    // ignore: only_throw_errors
    if (error != null) throw error;
    return pullResult;
  }
}

class _FakeCursors extends SyncCursorDao {
  _FakeCursors() : super(AppDatabase.forTesting(NativeDatabase.memory()));

  final Map<String, DateTime> storage = <String, DateTime>{};

  @override
  Future<DateTime?> get(String entity) async => storage[entity];

  @override
  Future<void> set(String entity, DateTime at) async {
    storage[entity] = at;
  }
}

class _FakeOutbox extends OutboxDao {
  _FakeOutbox(this._rows)
    : super(AppDatabase.forTesting(NativeDatabase.memory()));

  final List<OutboxRow> _rows;
  final List<int> acked = <int>[];
  final List<int> failed = <int>[];
  final List<int> bumped = <int>[];

  @override
  Future<List<OutboxRow>> peekAll() async => List.of(_rows);

  @override
  Future<void> ack(int seq) async {
    acked.add(seq);
    _rows.removeWhere((r) => r.seq == seq);
  }

  @override
  Future<void> markFailed(int seq) async {
    failed.add(seq);
    final index = _rows.indexWhere((r) => r.seq == seq);
    if (index != -1) {
      _rows[index] = _rows[index].copyWith(state: 'failed');
    }
  }

  @override
  Future<void> bumpAttempts(int seq) async {
    bumped.add(seq);
    final index = _rows.indexWhere((r) => r.seq == seq);
    if (index != -1) {
      _rows[index] = _rows[index].copyWith(attempts: _rows[index].attempts + 1);
    }
  }

  /// The current `attempts` count for [seq] in this fake's row list, or
  /// null if the row is gone (acked or otherwise removed).
  int? attemptsOf(int seq) {
    final index = _rows.indexWhere((r) => r.seq == seq);
    return index == -1 ? null : _rows[index].attempts;
  }

  /// The current `state` for [seq] in this fake's row list, or null if the
  /// row is gone (acked or otherwise removed).
  String? stateOf(int seq) {
    final index = _rows.indexWhere((r) => r.seq == seq);
    return index == -1 ? null : _rows[index].state;
  }

  @override
  Future<int> pendingCount() async =>
      _rows.where((r) => r.state == 'pending').length;
}

class _FakeDeletions implements DeletionsApplier {
  _FakeDeletions(this._events);

  final List<String> _events;
  int applyCount = 0;
  final List<DateTime?> sinceArgs = <DateTime?>[];

  /// When set, `applyDeletions` throws this. Clear it to simulate recovery.
  Object? applyThrows;

  @override
  Future<void> applyDeletions(DateTime? since) async {
    applyCount++;
    sinceArgs.add(since);
    _events.add('deletions');
    final error = applyThrows;
    // Rethrow whatever the test injected (Network/generic).
    // ignore: only_throw_errors
    if (error != null) throw error;
  }
}
