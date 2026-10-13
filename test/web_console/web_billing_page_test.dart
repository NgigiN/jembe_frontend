import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:farm_tracker/features/billing/data/models/entitlement_model.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_billing_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BillingRemoteDataSource {}

EntitlementModel _owner({int collaborators = 3, int seatsPaid = 0}) =>
    EntitlementModel.fromJson({
      'state': 'lapsed',
      'can_write': true,
      'is_owner': true,
      'collaborators': collaborators,
      'seats_paid': seatsPaid,
      'seat_cap': 20,
      'price_kes': 500 + 200 * collaborators,
      'base_kes': 500,
      'per_collaborator_kes': 200,
    });

Future<void> _pump(WidgetTester tester, _MockRemote remote) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: WebBillingPage(remote: remote)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => registerFallbackValue(0));

  testWidgets('shows the computed price for the current team', (tester) async {
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer((_) async => _owner());
    await _pump(tester, remote);

    // Three collaborators: 500 + 600.
    expect(find.textContaining('1,100'), findsWidgets);
  });

  testWidgets('a second submission while one is pending is explained, not '
      'dumped as a raw error', (tester) async {
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer((_) async => _owner());
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenThrow(
      const ServerException('a payment is already waiting for your M-Pesa PIN'),
    );
    await _pump(tester, remote);

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pumpAndSettle();

    // The farmer must understand the first push is still live, or they will
    // assume it failed and go looking for another way to pay.
    expect(find.textContaining('already waiting'), findsWidgets);
  });

  testWidgets('tapping pay twice starts only one charge', (tester) async {
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer((_) async => _owner());
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const CheckoutResult(reference: 'r1', amountKes: 1100);
    });
    await _pump(tester, remote);

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    verify(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).called(1);
  });

  testWidgets('tells the farmer to check their phone after the push', (
    tester,
  ) async {
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer((_) async => _owner());
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer(
      (_) async => const CheckoutResult(reference: 'r1', amountKes: 1100),
    );
    await _pump(tester, remote);

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Check your phone'), findsOneWidget);
  });

  testWidgets('confirms once the window moves', (tester) async {
    // Success is detected by seats_paid or paid_through CHANGING, never by
    // state == active: an owner renewing early is already active, so keying
    // off state would never confirm for them.
    final remote = _MockRemote();
    var call = 0;
    when(remote.getEntitlement).thenAnswer((_) async {
      call++;
      return call == 1 ? _owner() : _owner(seatsPaid: 3);
    });
    when(
      () => remote.checkout(
        seats: any(named: 'seats'),
        months: any(named: 'months'),
        phone: any(named: 'phone'),
      ),
    ).thenAnswer(
      (_) async => const CheckoutResult(reference: 'r1', amountKes: 1100),
    );
    await _pump(tester, remote);

    await tester.enterText(find.byType(TextField).first, '0722000000');
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.textContaining('Payment received'), findsOneWidget);
  });

  testWidgets('a non-owner is refused the page', (tester) async {
    final remote = _MockRemote();
    when(remote.getEntitlement).thenAnswer(
      (_) async => EntitlementModel.fromJson(const {
        'state': 'lapsed',
        'can_write': false,
        'is_owner': false,
      }),
    );
    await _pump(tester, remote);

    // Reachable by URL even though the nav hides it, so the page itself must
    // say no rather than render a payment form for somebody else's farm.
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('only the farm owner'), findsOneWidget);
  });

  group('billing nav entry', () {
    bool shows(FarmRole? role) => ConsoleNav.visible(
      ConsoleNav.farm,
      role,
    ).any((i) => i.label == 'Billing');

    test('only the owner sees it', () {
      expect(shows(FarmRole.owner), isTrue);
      expect(shows(FarmRole.manager), isFalse);
      expect(shows(FarmRole.worker), isFalse);
    });

    test('a null role is not treated as owner', () {
      expect(shows(null), isFalse);
    });
  });
}
