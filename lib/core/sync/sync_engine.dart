import 'dart:async';
import 'dart:math' as math;

import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/network/connectivity_service.dart';
import 'package:farm_tracker/core/sync/entity_syncer.dart';
import 'package:farm_tracker/core/sync/outbox.dart';
import 'package:farm_tracker/core/sync/sync_cursor_dao.dart';
import 'package:farm_tracker/core/sync/sync_status.dart';

/// Orchestrates offline-first synchronisation: drains the outbox (push) then
/// pulls server deltas, coordinating ordering, single-flight, connectivity
/// and exponential backoff. It owns no entity-specific I/O — that lives in the
/// injected [EntitySyncer]s and [DeletionsApplier] (wired in Task 7b).
///
/// ## Single-flight
/// At most one pass runs at a time. A [syncNow] call while a pass is running
/// sets a "run again" flag and returns the in-flight future; when the current
/// pass finishes it runs exactly once more, coalescing any number of
/// overlapping requests into a single extra pass.
///
/// ## Push then pull
/// Each pass drains the outbox FIFO first, then pulls per entity, then applies
/// deletions. If the push phase hits a transient ([NetworkException]) failure
/// the pass STOPS before pulling and schedules a backoff retry — the network
/// is unreliable right now, so pulling would likely fail too and waste effort.
///
/// ## Backoff
/// A transient failure schedules a [Timer] with exponential delay + jitter,
/// capped at `maxBackoff`; a clean pass resets it. The timer is created in the
/// ambient zone, so `fake_async` can drive it in tests.
class SyncEngine {
  SyncEngine({
    required OutboxDao outbox,
    required List<EntitySyncer> syncers,
    required SyncCursorDao cursors,
    required ConnectivityService connectivity,
    DeletionsApplier? deletions,
    DateTime Function()? now,
    math.Random? random,
    Duration baseBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 60),
  }) : _outbox = outbox,
       _cursors = cursors,
       _connectivity = connectivity,
       _deletions = deletions,
       _now = now ?? DateTime.now,
       _random = random ?? math.Random(),
       _baseBackoff = baseBackoff,
       _maxBackoff = maxBackoff,
       _syncers = {for (final syncer in syncers) syncer.entity: syncer};

  final OutboxDao _outbox;
  final Map<String, EntitySyncer> _syncers;
  final SyncCursorDao _cursors;
  final ConnectivityService _connectivity;
  final DeletionsApplier? _deletions;
  final DateTime Function() _now;
  final math.Random _random;
  final Duration _baseBackoff;
  final Duration _maxBackoff;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _status = const SyncStatus(phase: SyncPhase.idle);

  Future<void>? _inFlight;
  bool _runAgain = false;
  int _backoffAttempt = 0;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connectivitySub;
  bool _disposed = false;

  /// Live status transitions (broadcast; does not replay the last value —
  /// read [status] for the current snapshot).
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// The current status snapshot.
  SyncStatus get status => _status;

  /// Runs a sync pass, coalescing concurrent callers (see class docs).
  ///
  /// The returned future always completes normally (never with an error): a
  /// pass is fully guarded, so triggers that call `unawaited(syncNow())` can
  /// never surface an unhandled async error.
  Future<void> syncNow() {
    final existing = _inFlight;
    if (existing != null) {
      _runAgain = true;
      return existing;
    }
    final completer = Completer<void>();
    // Publish the in-flight marker BEFORE any async work starts, so the
    // completion handler that clears it can never run first and wedge the
    // engine — even in the (currently impossible) case of a synchronously
    // completing loop.
    _inFlight = completer.future;
    unawaited(
      _runLoop().catchError(_swallowLoopError).whenComplete(() {
        _inFlight = null;
        completer.complete();
      }),
    );
    return completer.future;
  }

  // _runLoop is designed never to throw (every pass is fully guarded); this is
  // belt-and-suspenders so a stray error can never wedge single-flight or
  // surface as an unhandled async error.
  void _swallowLoopError(Object error, StackTrace stackTrace) {}

  /// Wires triggers: re-syncs whenever connectivity is (re)gained.
  ///
  /// Launch/resume triggers are wired separately in Task 10; this only
  /// subscribes to the connectivity stream.
  void start() {
    _connectivitySub ??= _connectivity.onlineChanges.listen((online) {
      if (online) {
        unawaited(syncNow());
      }
    });
  }

  /// Cancels subscriptions/timers and closes the status stream.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = null;
    unawaited(_statusController.close());
  }

  // _inFlight lifecycle is owned by syncNow (assigned before the loop starts,
  // cleared in whenComplete), so the loop itself is a plain coalescing driver.
  Future<void> _runLoop() async {
    do {
      _runAgain = false;
      await _runOnePass();
    } while (_runAgain);
  }

  /// Runs exactly one online/offline pass. NEVER throws: every failure — from
  /// the push infra, the pull phase, or deletions — is mapped to a terminal
  /// status so the pass can't leave the engine stuck on `syncing`.
  Future<void> _runOnePass() async {
    var phase = SyncPhase.idle;
    DateTime? lastSyncedAt;
    var scheduleRetry = false;

    try {
      final online = await _connectivity.isOnline();
      if (!online) {
        // Offline: no-op this pass. Don't touch any syncer.
        await _emit(SyncPhase.idle);
        return;
      }

      await _emit(SyncPhase.syncing);

      final transientStop = await _pushPhase();
      if (!transientStop) {
        await _pullPhase();
      }

      if (transientStop) {
        phase = SyncPhase.error;
        scheduleRetry = true;
      } else {
        _resetBackoff();
        phase = SyncPhase.idle;
        lastSyncedAt = _now();
      }
    } on NetworkException {
      // A transient failure escaping the pull phase / deletions (or the push
      // infra) is handled exactly like a push transient stop: error + backoff.
      // A real LandSyncer.pull is a network call and WILL throw this offline.
      phase = SyncPhase.error;
      scheduleRetry = true;
    } on Object {
      // Any OTHER failure (a ServerException from the pull phase, a DAO error,
      // a syncer breaking the push contract): never crash the pass or surface
      // an unhandled async error. End in `error`, but do NOT auto-retry — a
      // persistent non-transient fault must not hot-loop; the next trigger
      // (connectivity regain / manual syncNow) retries. No logger is wired at
      // this layer yet (Task 10); the `error` status is the signal.
      phase = SyncPhase.error;
    }

    if (phase == SyncPhase.error) {
      await _emit(SyncPhase.error);
      if (scheduleRetry) {
        _scheduleRetry();
      }
    } else {
      await _emit(SyncPhase.idle, lastSyncedAt: lastSyncedAt);
    }
  }

  /// Drains the outbox FIFO. Returns true if a transient failure stopped the
  /// phase early (remaining entries left queued for the backoff retry).
  Future<bool> _pushPhase() async {
    final rows = await _outbox.peekAll();
    for (final row in rows) {
      if (row.state != 'pending') continue;
      final syncer = _syncers[row.entity];
      if (syncer == null) continue; // no adapter registered → skip.
      try {
        await syncer.push(row);
        await _outbox.ack(row.seq);
      } on NetworkException {
        return true; // transient → stop, keep this + remaining entries.
      } on ServerException {
        await _outbox.markFailed(row.seq); // permanent → park, continue.
      }
    }
    return false;
  }

  Future<void> _pullPhase() async {
    // Snapshot cursors BEFORE pulling so deletions ask from the same point.
    final preCursors = <String, DateTime?>{};
    for (final syncer in _syncers.values) {
      preCursors[syncer.entity] = await _cursors.get(syncer.entity);
    }

    for (final syncer in _syncers.values) {
      final newCursor = await syncer.pull(preCursors[syncer.entity]);
      if (newCursor != null) {
        await _cursors.set(syncer.entity, newCursor);
      }
    }

    final deletions = _deletions;
    if (deletions != null) {
      // /sync/deletions is a single global endpoint, so ask from the OLDEST
      // per-entity cursor: any newer cursor could skip deletions that
      // happened between the oldest and newest entity. Deletions are
      // idempotent, so re-seeing already-applied ones is harmless.
      await deletions.applyDeletions(_oldestCursor(preCursors.values));
    }
  }

  DateTime? _oldestCursor(Iterable<DateTime?> cursors) {
    DateTime? oldest;
    for (final cursor in cursors) {
      if (cursor == null) {
        return null; // an unsynced entity needs all deletions.
      }
      if (oldest == null || cursor.isBefore(oldest)) {
        oldest = cursor;
      }
    }
    return oldest;
  }

  void _resetBackoff() {
    _backoffAttempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _backoffDelay(_backoffAttempt);
    _backoffAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(syncNow());
    });
  }

  /// Exponential backoff with "equal jitter", capped at `maxBackoff`:
  /// delay ∈ [capped/2, capped] where capped = min(base·2^attempt, max).
  Duration _backoffDelay(int attempt) {
    final expMs = _baseBackoff.inMilliseconds * math.pow(2, attempt).toDouble();
    final cappedMs = math
        .min(expMs, _maxBackoff.inMilliseconds.toDouble())
        .toInt();
    final half = cappedMs ~/ 2;
    final jitter = half > 0 ? _random.nextInt(half + 1) : 0;
    return Duration(milliseconds: half + jitter);
  }

  Future<void> _emit(SyncPhase phase, {DateTime? lastSyncedAt}) async {
    var pending = _status.pendingCount;
    try {
      pending = await _outbox.pendingCount();
    } on Object {
      // A broken local pending-count read must never wedge a status
      // transition; fall back to the last known count.
    }
    final next = SyncStatus(
      phase: phase,
      lastSyncedAt: lastSyncedAt ?? _status.lastSyncedAt,
      pendingCount: pending,
    );
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
