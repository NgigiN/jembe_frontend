import 'package:farm_tracker/core/database/app_database.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/sync/fk_resolver.dart';

/// Per-entity sync adapter driven by the `SyncEngine`.
///
/// One [EntitySyncer] knows how to talk to the server for a single entity
/// kind (e.g. `'land'`). The engine owns orchestration (ordering,
/// single-flight, backoff, cursors); a syncer only implements the two I/O
/// halves against the remote datasource + local mirror.
abstract class EntitySyncer {
  /// The outbox `entity` tag this syncer handles (e.g. `'land'`).
  String get entity;

  /// Applies exactly ONE outbox [entry] to the server and reconciles the
  /// local id (e.g. writing back the server id on a create).
  ///
  /// The [resolver] translates FK fields that reference an unsynced parent;
  /// a syncer with no FKs ignores it. Throwing [SyncDependencyException]
  /// parks the entry for a later pass.
  ///
  /// SUCCESS is a normal return. On failure it MUST throw one of:
  /// - [NetworkException] — transient/offline; the engine keeps the entry
  ///   queued, stops the push phase and schedules a backoff retry.
  /// - [ServerException] — permanent (server-side, includes 4xx); the engine
  ///   parks the entry (`markFailed`) and continues with the next one.
  Future<void> push(OutboxRow entry, FkResolver resolver);

  /// Fetches server changes strictly after [since] (null = full pull),
  /// upserts them into the local mirror, and returns the greatest
  /// `updatedAt` observed (the new cursor), or null if nothing changed.
  Future<DateTime?> pull(DateTime? since);

  /// `true` = this syncer advances a per-entity pull cursor (delta sync).
  /// `false` = it never returns a cursor (full re-fetch / no-op pull), so
  /// the engine must NOT let its perpetual-null cursor force a full
  /// deletions replay (see `SyncEngine._pullPhase`).
  bool get hasCursor => true;
}

/// Applies server-side hard deletions (tombstones) to the local mirror.
///
/// The engine calls this once per pull phase, after every syncer's
/// [EntitySyncer.pull] has run. Task 7b supplies the real `/sync/deletions`
/// implementation.
// ignore: one_member_abstracts
abstract class DeletionsApplier {
  /// Removes locally every row the server reports deleted since [since]
  /// (null = all known deletions). Implementations MUST be idempotent.
  Future<void> applyDeletions(DateTime? since);
}
