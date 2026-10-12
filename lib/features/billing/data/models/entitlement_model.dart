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
      state: BillingState.fromWire((json['state'] ?? 'free').toString()),
      canWrite: json['can_write'] as bool? ?? true,
      isOwner: json['is_owner'] as bool? ?? false,
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

  static int _int(Object? raw, int fallback) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  /// `YYYY-MM-DD` or null. A malformed value reads as absent: a date we
  /// cannot parse is not worth crashing over, and every consumer already
  /// handles null.
  static DateTime? _day(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse('${raw}T00:00:00Z');
  }
}
