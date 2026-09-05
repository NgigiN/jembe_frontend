import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
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
}) {
  return OutboxRow(
    seq: seq,
    entity: entity,
    op: op,
    clientUuid: clientUuid,
    payload: '{}',
    attempts: 0,
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

  SyncEngine build({List<OutboxRow> rows = const []}) {
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
    engine = build(rows: [_row(1), _row(2, clientUuid: 'b')]);
    syncer.onPush = (row) =>
        row.seq == 1 ? const ServerException('4xx') : null;

    await engine.syncNow();

    expect(syncer.pushCount, 2); // both attempted
    expect(outbox.failed, [1]); // parked
    expect(outbox.acked, [2]); // second succeeded
    // Permanent failures don't flip the pass to error; pull still runs.
    expect(engine.status.phase, SyncPhase.idle);
    expect(syncer.pullCount, 1);
  });

  test('entry whose entity has no registered syncer is skipped, not crashed',
      () async {
    engine = build(rows: [_row(1, entity: 'ghost'), _row(2)]);

    await engine.syncNow();

    // ghost skipped, land pushed + acked.
    expect(outbox.acked, [2]);
    expect(engine.status.phase, SyncPhase.idle);
  });

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
      engine = build(rows: [_row(1), _row(2, clientUuid: 'b')]);
      syncer.onPush = (row) =>
          row.seq == 1 ? NetworkException() : null;

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

  test('generic pull error: status ends error, pass does not wedge, syncNow '
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
  });

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

  test('start(): regaining connectivity triggers a sync', () async {
    engine = build(rows: [_row(1)])..start();

    connectivity.emit(true);
    // Let the stream event + the sync pass drain.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(syncer.pushCount, greaterThanOrEqualTo(1));
    expect(outbox.acked, [1]);
  });

  test('statusStream emits syncing then idle across a successful pass',
      () async {
    engine = build(rows: [_row(1)]);
    final phases = <SyncPhase>[];
    final sub = engine.statusStream.listen((s) => phases.add(s.phase));

    await engine.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    expect(phases.first, SyncPhase.syncing);
    expect(phases.last, SyncPhase.idle);
  });
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
  Future<void> push(OutboxRow entry) async {
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
