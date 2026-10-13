import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/billing/domain/entities/entitlement.dart';
import 'package:farm_tracker/features/billing/presentation/widgets/read_only_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Entitlement _of(Map<String, dynamic> json) => EntitlementModel.fromJson(json);

void main() {
  group('ReadOnlyBanner.appliesTo', () {
    test('a collaborator on a lapsed farm sees it', () {
      expect(
        ReadOnlyBanner.appliesTo(
          _of(const {'state': 'lapsed', 'can_write': false, 'is_owner': false}),
        ),
        isTrue,
      );
    });

    test('the OWNER of a lapsed farm never sees it — they keep full write '
        'access, because a failed payment must not stop a farmer recording '
        'their own harvest', () {
      expect(
        ReadOnlyBanner.appliesTo(
          _of(const {'state': 'lapsed', 'can_write': true, 'is_owner': true}),
        ),
        isFalse,
      );
    });

    test('an active farm sees nothing', () {
      expect(
        ReadOnlyBanner.appliesTo(
          _of(const {'state': 'active', 'can_write': true, 'is_owner': false}),
        ),
        isFalse,
      );
    });

    test('a free solo account sees nothing — it has no team to degrade', () {
      expect(
        ReadOnlyBanner.appliesTo(
          _of(const {'state': 'free', 'can_write': true, 'is_owner': true}),
        ),
        isFalse,
      );
    });

    test('a trialing farm sees nothing', () {
      expect(
        ReadOnlyBanner.appliesTo(
          _of(const {
            'state': 'trialing',
            'can_write': true,
            'is_owner': false,
          }),
        ),
        isFalse,
      );
    });

    test('a grandfathered farm sees nothing', () {
      expect(
        ReadOnlyBanner.appliesTo(
          _of(const {
            'state': 'grandfathered',
            'can_write': true,
            'is_owner': false,
          }),
        ),
        isFalse,
      );
    });
  });

  testWidgets('renders nothing at all when it does not apply', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadOnlyBanner.forEntitlement(
            _of(const {'state': 'active', 'can_write': true}),
          ),
        ),
      ),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.textContaining('read-only'), findsNothing);
  });

  testWidgets('says what happened and that nothing was lost', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadOnlyBanner.forEntitlement(
            _of(const {
              'state': 'lapsed',
              'can_write': false,
              'is_owner': false,
            }),
          ),
        ),
      ),
    );

    // The reassurance matters as much as the notice: someone who cannot save
    // their work needs to know their earlier work is safe.
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.textContaining('nothing has been lost'), findsOneWidget);
  });

  testWidgets('without an EntitlementCubit above it, renders nothing and '
      'does not throw', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReadOnlyBanner())),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('read-only'), findsNothing);
  });
}
