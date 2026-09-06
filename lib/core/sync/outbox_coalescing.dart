import 'package:equatable/equatable.dart';

/// The kind of mutation an [OutboxIntent] represents.
enum OutboxOp {
  /// Row does not exist server-side yet; create it.
  create,

  /// Row exists server-side; update it in place.
  update,

  /// Row should be removed server-side.
  delete,
}

/// An immutable, queued mutation for a single locally-identified row.
///
/// [clientUuid] identifies the row across the offline/online boundary.
/// [payload] is the JSON snapshot to sync for [OutboxOp.create] and
/// [OutboxOp.update]; it is `null` for [OutboxOp.delete].
class OutboxIntent extends Equatable {
  const OutboxIntent({
    required this.op,
    required this.clientUuid,
    required this.entity,
    this.payload,
  });

  final OutboxOp op;
  final String clientUuid;
  final String entity;
  final String? payload;

  @override
  List<Object?> get props => [op, clientUuid, entity, payload];
}

/// Merges [incoming] into [pending], applying the outbox
/// coalescing/annihilation rules (spec §3.2) against whichever entry in
/// [pending] shares [incoming]'s `clientUuid`. Entries for other
/// `clientUuid`s are returned untouched and in their original order.
///
/// Rules, for the same `clientUuid`'s not-yet-synced entry:
/// - existing `create` + incoming `update` -> single `create` carrying the
///   update's payload (the row never existed server-side; just create it
///   with the latest state).
/// - existing `create` + incoming `delete` -> annihilate: remove both, emit
///   nothing for this `clientUuid` (a scratch row made and deleted offline
///   never reaches the server).
/// - existing `update` + incoming `update` -> single `update`, latest
///   payload.
/// - existing `update` + incoming `delete` -> single `delete`.
/// - no existing entry for the `clientUuid` -> append [incoming] as-is.
/// - existing `delete` + incoming anything -> defensive: a delete is
///   terminal, so nothing should follow it for the same `clientUuid` in
///   practice. Rather than crash, the existing `delete` is kept and the
///   incoming intent is dropped.
List<OutboxIntent> coalesce(
  List<OutboxIntent> pending,
  OutboxIntent incoming,
) {
  final existingIndex = pending.indexWhere(
    (entry) => entry.clientUuid == incoming.clientUuid,
  );

  if (existingIndex == -1) {
    return [...pending, incoming];
  }

  final existing = pending[existingIndex];
  final result = [...pending];

  switch ((existing.op, incoming.op)) {
    case (OutboxOp.create, OutboxOp.update):
      result[existingIndex] = OutboxIntent(
        op: OutboxOp.create,
        clientUuid: existing.clientUuid,
        entity: existing.entity,
        payload: incoming.payload,
      );
    case (OutboxOp.create, OutboxOp.delete):
      result.removeAt(existingIndex);
    case (OutboxOp.update, OutboxOp.update):
      result[existingIndex] = OutboxIntent(
        op: OutboxOp.update,
        clientUuid: existing.clientUuid,
        entity: existing.entity,
        payload: incoming.payload,
      );
    case (OutboxOp.update, OutboxOp.delete):
      result[existingIndex] = OutboxIntent(
        op: OutboxOp.delete,
        clientUuid: existing.clientUuid,
        entity: existing.entity,
      );
    case (OutboxOp.delete, _):
      // A delete is terminal for this clientUuid. Nothing should realistically
      // follow it, but defend against it anyway by keeping the existing
      // delete and dropping the incoming intent rather than crashing.
      break;
    case (OutboxOp.create, OutboxOp.create):
    case (OutboxOp.update, OutboxOp.create):
      // Not reachable per spec (a clientUuid is only ever created once), but
      // handled defensively by preferring the incoming intent's payload
      // under the existing op so we never throw on an unexpected sequence.
      result[existingIndex] = OutboxIntent(
        op: existing.op,
        clientUuid: existing.clientUuid,
        entity: existing.entity,
        payload: incoming.payload,
      );
  }

  return result;
}
