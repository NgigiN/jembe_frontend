import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';

class EntitlementModel extends Entitlement {
  const EntitlementModel({
    required super.state,
    required super.canWrite,
    required super.isOwner,
    required super.collaborators,
    required super.seatsPaid,
    required super.seatCap,
    required super.paidThrough,
    required super.trialEndsAt,
    required super.priceKes,
    required super.baseKes,
    required super.perCollaboratorKes,
    required super.aiQuestionsPerDay,
  });

  /// Every field is read defensively. This endpoint decides whether the app
  /// offers to write, so a parse failure must degrade to permissive rather
  /// than throw — a thrown error here would surface as a blank screen on the
  /// page people reach to invite someone.
  factory EntitlementModel.fromJson(Map<String, dynamic> json) {
    return EntitlementModel(
      state: BillingState.fromWire(json['state']?.toString() ?? ''),
      canWrite: _bool(json['can_write'], true),
      isOwner: _bool(json['is_owner'], false),
      collaborators: _int(json['collaborators'], 0),
      seatsPaid: _int(json['seats_paid'], 0),
      seatCap: _int(json['seat_cap'], 20),
      paidThrough: _day(json['paid_through']),
      trialEndsAt: _day(json['trial_ends_at']),
      priceKes: _int(json['price_kes'], 0),
      baseKes: _int(json['base_kes'], 500),
      perCollaboratorKes: _int(json['per_collaborator_kes'], 200),
      aiQuestionsPerDay: _int(json['ai_questions_per_day'], 3),
    );
  }

  /// `as bool?` THROWS on a non-bool, non-null value — it does not return
  /// null. A server sending `"yes"` or `1` for a flag would otherwise take
  /// down the page people reach to invite someone, with an uncaught TypeError.
  static bool _bool(Object? raw, bool fallback) {
    if (raw is bool) return raw;
    return fallback;
  }

  static int _int(Object? raw, int fallback) {
    if (raw is int) return raw;
    // isFinite guards Infinity and NaN, where toInt() throws
    // UnsupportedError. jsonDecode turns `1e999` into Infinity.
    if (raw is num) return raw.isFinite ? raw.toInt() : fallback;
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  /// `YYYY-MM-DD`, a full ISO timestamp, or null.
  ///
  /// Three things here are deliberate. A bare date is forced to UTC midnight,
  /// because `DateTime.tryParse('2026-11-11')` yields LOCAL midnight and in
  /// Kenya (UTC+3) that is the previous day in UTC — a paid window would
  /// expire a day early. A value that already carries a time is parsed as-is
  /// rather than having one appended, which would make it unparseable and
  /// read as "never paid". And a date Dart normalises into nonsense — it
  /// turns `0000-00-00` into the year -1 rather than rejecting it — is
  /// treated as absent, which falls open instead of showing a paid-up farm
  /// as overdue.
  static DateTime? _day(Object? raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(
      text.length == 10 ? '${text}T00:00:00Z' : text,
    );
    if (parsed == null) return null;
    final utc = parsed.toUtc();
    // This product did not exist before 2020. Anything earlier is a server
    // bug, and reading it as absent is the safe direction.
    return utc.year < 2020 ? null : utc;
  }
}
