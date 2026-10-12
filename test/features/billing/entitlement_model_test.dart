import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntitlementModel.fromJson', () {
    test('parses a full active response', () {
      final e = EntitlementModel.fromJson(const {
        'state': 'active',
        'can_write': true,
        'is_owner': true,
        'collaborators': 3,
        'seats_paid': 3,
        'seat_cap': 20,
        'paid_through': '2026-11-11',
        'trial_ends_at': null,
        'price_kes': 1100,
        'base_kes': 500,
        'per_collaborator_kes': 200,
        'ai_questions_per_day': 10,
      });

      expect(e.state, BillingState.active);
      expect(e.canWrite, isTrue);
      expect(e.isOwner, isTrue);
      expect(e.collaborators, 3);
      expect(e.seatsPaid, 3);
      expect(e.seatCap, 20);
      expect(e.paidThrough, DateTime.utc(2026, 11, 11));
      expect(e.trialEndsAt, isNull);
      expect(e.priceKes, 1100);
      expect(e.aiQuestionsPerDay, 10);
    });

    test('parses null dates, which is the ordinary state for every account '
        'that has never paid or trialed', () {
      final e = EntitlementModel.fromJson(const {
        'state': 'free',
        'can_write': true,
        'is_owner': true,
        'collaborators': 0,
        'seats_paid': 0,
        'seat_cap': 20,
        'paid_through': null,
        'trial_ends_at': null,
        'price_kes': 0,
        'base_kes': 500,
        'per_collaborator_kes': 200,
        'ai_questions_per_day': 3,
      });

      expect(e.state, BillingState.free);
      expect(e.paidThrough, isNull);
      expect(e.trialEndsAt, isNull);
    });

    test('survives missing keys rather than throwing — a server that grows a '
        'field must not crash an older build', () {
      final e = EntitlementModel.fromJson(const {'state': 'lapsed'});

      expect(e.state, BillingState.lapsed);
      expect(e.collaborators, 0);
      expect(e.seatCap, 20);
      expect(e.paidThrough, isNull);
    });

    test('an unrecognised state falls back to free rather than throwing', () {
      final e = EntitlementModel.fromJson(const {'state': 'something_new'});

      expect(e.state, BillingState.free);
    });

    test('a malformed date is treated as absent, not as a crash', () {
      final e = EntitlementModel.fromJson(const {
        'state': 'active',
        'paid_through': 'not-a-date',
      });

      expect(e.paidThrough, isNull);
    });
  });

  group('Entitlement', () {
    test('permissive() falls OPEN — a failed lookup must never make a paying '
        'farm read-only', () {
      const e = Entitlement.permissive();

      expect(e.canWrite, isTrue);
    });

    test('priceFor does the ladder locally so the seat picker can show a '
        'price before any request', () {
      final e = EntitlementModel.fromJson(const {
        'state': 'free',
        'base_kes': 500,
        'per_collaborator_kes': 200,
      });

      expect(e.priceFor(0), 0);
      expect(e.priceFor(1), 700);
      expect(e.priceFor(3), 1100);
      expect(e.priceFor(5), 1500);
      expect(e.priceFor(20), 4500);
    });

    test('isLapsed is the only thing the read-only gate asks about', () {
      final lapsed = EntitlementModel.fromJson(const {
        'state': 'lapsed',
        'can_write': false,
        'is_owner': false,
      });
      final trialing = EntitlementModel.fromJson(const {
        'state': 'trialing',
        'can_write': true,
      });

      expect(lapsed.isLapsed, isTrue);
      expect(trialing.isLapsed, isFalse);
    });
  });
}
