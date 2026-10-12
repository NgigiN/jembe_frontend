import 'package:equatable/equatable.dart';

/// What an account's plan is doing right now.
///
/// [free] and [lapsed] both mean "may not add anyone", but they are not the
/// same thing: free has never had a team, lapsed had one and lost the ability
/// to edit. The two get different screens.
enum BillingState {
  free,
  trialing,
  active,
  lapsed,
  grandfathered;

  /// Falls back to [free] on anything unrecognised. A server that adds a new
  /// state must not crash a build that predates it.
  static BillingState fromWire(String raw) {
    return BillingState.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => BillingState.free,
    );
  }
}

/// The viewing user's entitlement in the current farm.
///
/// Note what this is NOT: an authorisation decision. The server never refuses
/// a write on billing grounds, because the offline outbox treats any 4xx as
/// permanent and would mark every queued row on the device as failed. This is
/// advisory, and the app's job is to not offer a write it knows is unpaid —
/// so the write never enters the outbox in the first place.
class Entitlement extends Equatable {
  const Entitlement({
    required this.state,
    required this.canWrite,
    required this.isOwner,
    required this.collaborators,
    required this.seatsPaid,
    required this.seatCap,
    required this.paidThrough,
    required this.trialEndsAt,
    required this.priceKes,
    required this.baseKes,
    required this.perCollaboratorKes,
    required this.aiQuestionsPerDay,
  });

  /// The fall-open default, used whenever entitlement is unknown.
  ///
  /// It must stay permissive. Falling closed would mean a dropped request on
  /// a Kenyan mobile network puts a paying farm into read-only — a worse
  /// product than having no gate at all.
  const Entitlement.permissive()
    : state = BillingState.free,
      canWrite = true,
      isOwner = false,
      collaborators = 0,
      seatsPaid = 0,
      seatCap = 20,
      paidThrough = null,
      trialEndsAt = null,
      priceKes = 0,
      baseKes = 500,
      perCollaboratorKes = 200,
      aiQuestionsPerDay = 3;

  final BillingState state;
  final bool canWrite;
  final bool isOwner;
  final int collaborators;
  final int seatsPaid;
  final int seatCap;
  final DateTime? paidThrough;
  final DateTime? trialEndsAt;
  final int priceKes;
  final int baseKes;
  final int perCollaboratorKes;
  final int aiQuestionsPerDay;

  bool get isLapsed => state == BillingState.lapsed;

  /// The monthly price at a given team size, computed locally so the seat
  /// picker can show a number as the user drags it without a round trip.
  /// Mirrors the server's ladder exactly: zero collaborators is free, because
  /// the base applies only once there is a team.
  int priceFor(int collaborators) {
    if (collaborators <= 0) return 0;
    return baseKes + (perCollaboratorKes * collaborators);
  }

  @override
  List<Object?> get props => [
    state,
    canWrite,
    isOwner,
    collaborators,
    seatsPaid,
    seatCap,
    paidThrough,
    trialEndsAt,
    priceKes,
    baseKes,
    perCollaboratorKes,
    aiQuestionsPerDay,
  ];
}
